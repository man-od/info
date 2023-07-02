--  1) Написать функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде
DROP FUNCTION IF EXISTS func_transferredPoints_humanView CASCADE;
CREATE OR REPLACE FUNCTION func_transferredPoints_humanView()
RETURNS TABLE(
Peer1 varchar,
Peer2 varchar,
PointsAmount integer
) AS $BODY$
SELECT t1.checkingpeer AS Peer1, t1.checkedpeer AS Peer2, -1*(t1.pointsamount-t2.pointsamount) AS PointsAmount
FROM transferredpoints AS t1
JOIN transferredpoints AS t2 ON t1.checkingpeer = t2.checkedpeer AND t1.checkedpeer = t2.checkingpeer AND
t1.id < t2.id

$BODY$ LANGUAGE SQL;

-- SELECT * FROM func_transferredPoints_humanView()

--  2) Написать функцию, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP
DROP FUNCTION IF EXISTS func_PeerTaskXP CASCADE;
CREATE OR REPLACE FUNCTION func_PeerTaskXP()
RETURNS TABLE(
Peer varchar,
Task varchar,
XP integer
) AS $BODY$
SELECT checks.peer AS Peer, checks.task AS Task, xp.xpamount AS XP
    FROM checks
    JOIN xp ON xp."check" = checks.id
    ORDER BY Peer, task, XP;
$BODY$ LANGUAGE SQL;

-- select * from func_PeerTaskXP();

--  3) Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня
CREATE OR REPLACE FUNCTION func_allDayTracking(targetDate date)
RETURNS SETOF VARCHAR AS $BODY$
    SELECT ine.peer
    FROM (SELECT * FROM timetracking WHERE date = targetDate AND
                                         state = 1) AS ine                          -- Строки только входа
    LEFT JOIN (SELECT * FROM timetracking WHERE date = targetDate AND
                                         state = 2) AS oute ON ine.peer = oute.peer -- Строки только выхода
    WHERE oute.peer IS null;  -- JOIN LEFT c Null
$BODY$ LANGUAGE SQL;

-- SELECT * FROM func_allDayTracking('2023-07-01');



-- 4) Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints
DROP PROCEDURE IF EXISTS count_change_points_origin CASCADE;
CREATE OR REPLACE PROCEDURE count_change_points_origin(INOUT result_cursor refcursor)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Открытие курсора и запись туда временной таблицы
    OPEN result_cursor FOR
    WITH tab1 AS ( -- сумма заработанных пирпоинтов для всех пиров
    SELECT checkingpeer, SUM(pointsamount) AS sum FROM transferredpoints GROUP BY checkingpeer
),
    tab2 AS (  -- сумма отданных пир поинтов для всех пиров
    SELECT checkedpeer, SUM(pointsamount) AS dif FROM transferredpoints GROUP BY checkedpeer
)
-- выводим пир и сколько он заработал минус сколько потерял
SELECT checkingpeer AS peer, tab1.sum-tab2.dif AS PointsChange FROM tab1
JOIN tab2 ON tab1.checkingpeer = tab2.checkedpeer
    ORDER BY 1,2;
END;$$;

-- BEGIN;
--     CALL count_change_points_origin('cursor');
--     FETCH ALL FROM cursor;
--     CLOSE cursor;
-- END;


-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3
DROP PROCEDURE IF EXISTS count_change_points_Part3_1 CASCADE;
CREATE OR REPLACE PROCEDURE count_change_points_Part3_1(INOUT result_cursor refcursor)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Открытие курсора и запись туда временной таблицы
    OPEN result_cursor FOR
    WITH temp AS ( -- временная таблица для функции из Part 3.1
    SELECT * FROM func_transferredPoints_humanView()
    ),
    tab1 AS ( -- сумма заработан0.2ных пирпоинтов для всех пиров
    SELECT peer1, SUM(pointsamount) AS sum FROM temp GROUP BY peer1
),
    tab2 AS (  -- сумма отданных пир поинтов для всех пиров
    SELECT peer2, SUM(pointsamount) AS dif FROM temp GROUP BY peer2
)
    -- выводим пир и сколько он заработал минус сколько потерял
    SELECT trab.peer, coalesce(tab2.dif, 0) - coalesce(tab1.sum, 0) FROM
    (SELECT peer1 AS peer FROM tab1
    UNION
    SELECT peer2 AS peer FROM tab2) AS trab
    FULL JOIN tab1 ON tab1.peer1 = trab.peer
    FULL JOIN tab2 ON tab2.peer2 = trab.peer
    ORDER BY 1, 2;
END;
$$;

-- BEGIN;
-- CALL count_change_points_Part3_1('cursor');
-- FETCH ALL FROM cursor;
-- CLOSE cursor;
-- END;


-- 6) Определить самое часто проверяемое задание за каждый день
DROP PROCEDURE IF EXISTS find_popular_task CASCADE;
CREATE OR REPLACE PROCEDURE find_popular_task(in cursor refcursor)
LANGUAGE plpgsql AS $$
BEGIN
OPEN cursor FOR
    WITH t1 as (
    SELECT checks.Task, Date, count(checks.Task) as counts from checks
    group by Date, checks.Task)

    SELECT Date, n.Task FROM t1 as n
    WHERE counts = (
       SELECT MAX(counts)
       FROM (select * from t1 where n.Date = t1.Date) as res
    )
    ORDER BY 1 DESC, 2;
END;
$$;

-- BEGIN;
--     CALL find_popular_task('cursor');
--     FETCH ALL IN "cursor";
--     CLOSE cursor;
-- END;

-- 7) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания
DROP PROCEDURE IF EXISTS get_peers_with_closed_branches CASCADE;
CREATE OR REPLACE PROCEDURE get_peers_with_closed_branches(inout cursor refcursor,
    branch VARCHAR
) AS $$
BEGIN
    OPEN cursor FOR
    WITH t AS (
    -- Выводим имена пиров и даты сдачи проекта
        SELECT DISTINCT ch.Peer, ch.Date
        FROM checks ch
        JOIN verter v ON v."check" = ch.id
        WHERE ch.Task = (
            SELECT Title
            FROM Tasks
            WHERE Title  ~ ('^'|| branch || '[0-9]' || '*')
            ORDER BY Title DESC
        LIMIT 1) AND v.state = 'Success'
        ORDER BY ch.Date
    )
    SELECT *
    FROM t;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
--     CALL get_peers_with_closed_branches('cursor', 'C');
--     FETCH ALL IN "cursor";
--     CLOSE cursor;
-- END;


-- 8) Определить, к какому пиру стоит идти на проверку каждому обучающемуся
DROP PROCEDURE IF EXISTS recommendedpeers_from_friends CASCADE;
CREATE OR REPLACE PROCEDURE recommendedpeers_from_friends(inout cursor refcursor)
LANGUAGE plpgsql AS $$
BEGIN
    OPEN cursor FOR
    WITH t1 AS (
        SELECT t1.Peer, t1.Recommendedpeer
        FROM (SELECT DISTINCT ON (Peer)
              p.Peer, r.recommendedpeer, count(r.recommendedpeer)
        FROM (SELECT Peer1 AS Peer, Peer2 AS Friend
            FROM Friends
            UNION ALL
            SELECT Peer2 AS Peer, Peer1 AS Friend
        FROM Friends ) AS p
    LEFT JOIN Recommendations r ON r.peer = p.friend
    WHERE r.recommendedpeer IS NOT NULL AND p.Peer <> r.recommendedpeer
    GROUP BY 1,2
    ORDER BY 1,3 DESC)
    t1)
    SELECT * FROM t1;
END;
$$;

-- BEGIN;
--     CALL recommendedpeers_from_friends('cursor');
--     FETCH ALL IN "cursor";
--     CLOSE cursor;
-- END;


-- 9) Определить процент пиров, которые:
-- Приступили только к блоку 1 || Приступили только к блоку 2
-- Приступили к обоим || Не приступили ни к одному
DROP PROCEDURE IF EXISTS percentage_of_peers_that_started_blocks CASCADE;
CREATE OR REPLACE PROCEDURE percentage_of_peers_that_started_blocks(inout cursor refcursor,
    block1 VARCHAR,
    block2 VARCHAR
)AS $$
BEGIN
    OPEN cursor FOR
    WITH proc_block1 AS (
    SELECT DISTINCT ON (peer) *
    FROM checks
    WHERE task ~ ('^'|| block1 || '1_' || '*')
),
    proc_block2 AS (
    SELECT DISTINCT ON (peer) *
    FROM checks
    WHERE task ~ ('^'|| block2 || '1_' || '*')
),
    proc_both_blocks AS(
    SELECT pb1.peer  FROM proc_block1 pb1
    LEFT JOIN proc_block2 pb2 ON pb1.peer = pb2.peer
    WHERE pb1.peer IS NOT NULL AND pb2.peer IS NOT NULL
    ),
   all_blocks AS (
    SELECT * FROM proc_block1
    UNION
    SELECT * FROM proc_block2
),
    didnt_started AS (
        SELECT *
        FROM peers p
        WHERE p.nickname NOT IN (SELECT peer FROM all_blocks)
    )
    SELECT
        ROUND(100 * (count(p1.peer)::numeric / (SELECT count(*) FROM peers)), 2) AS StartedBlock1,
        ROUND(100 * (count(p2.peer)::numeric / (SELECT count(*) FROM peers)), 2) AS StartedBlock2,
        ROUND(100 * (count(b.peer)::numeric / (SELECT count(*) FROM peers)), 2) AS StartedBothBlocks,
        ROUND(100 * (count(d.nickname)::numeric / (SELECT count(*) FROM peers)), 2) AS DidntStartAnyBlock
    FROM proc_block1 p1
    FULL JOIN proc_block2 p2 ON p1.peer = p2.peer
    FULL JOIN  proc_both_blocks b ON p1.peer = b.peer
    FULL JOIN didnt_started d ON p1.peer = d.nickname
    WHERE p1.peer IS NULL OR d.nickname IS NULL;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
--     CALL percentage_of_peers_that_started_blocks('cursor', 'C','L');
--     FETCH ALL IN "cursor";
-- END;



-- 10) Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения
CREATE OR REPLACE PROCEDURE check_task_birthday(in cursor refcursor)
LANGUAGE plpgsql AS $$
BEGIN
    OPEN cursor FOR
    WITH birthday_checks AS (
        SELECT Nickname, coalesce (xp.Check, 0) AS main_status
        FROM (select * from checks
            join peers p on p.Nickname = checks.Peer
            where (select extract(day from Birthday)) = (select extract(day from Date))
            and (select extract(month from Birthday)) = (select extract(month from Date))) as b

        left join xp on xp.Check = b.ID
        group by Nickname, main_status)

    SELECT round((SELECT count(distinct b.Nickname) FROM birthday_checks b where main_status > 0)::numeric * 100
            /
           count(peers.Nickname)::numeric) as SuccessfulChecks,
           round((SELECT count(distinct b.Nickname) FROM birthday_checks b where main_status = 0)::numeric * 100
            /
           count(peers.Nickname)::numeric) as UnsuccessfulChecks  from peers;
END;$$;

-- BEGIN;
--     CALL check_task_birthday('cursor');
--     FETCH ALL FROM "cursor";
-- END;


-- 11) Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3
DROP PROCEDURE IF EXISTS find_peer_task3 CASCADE;
CREATE OR REPLACE PROCEDURE find_peer_task3(
    task1 VARCHAR,
    task2 VARCHAR,
    task3 VARCHAR,
    IN cursor REFCURSOR
)
LANGUAGE plpgsql AS $$
BEGIN
    OPEN cursor FOR
    WITH t1 AS (
        SELECT Peer
        FROM func_PeerTaskXP()
        WHERE task1 IN (
            SELECT task
            FROM func_PeerTaskXP()
        )
    ),
    t2 AS (
        SELECT Peer
        FROM func_PeerTaskXP()
        WHERE task2 IN (
            SELECT task
            FROM func_PeerTaskXP()
        )
    ),
    t3 AS (
        SELECT Peer
        FROM func_PeerTaskXP()
        WHERE task3 NOT IN (
            SELECT task
            FROM func_PeerTaskXP()
        )
    )
    SELECT * FROM (
        (select * from t1)
        intersect
        (select * from t2)
        intersect
        (select * from t3)
    ) as t_res;
END;
$$;

-- BEGIN;
--     CALL find_peer_task3('C1_S21_BashUtils', 'C2_S21_String+', 'C5_S21_matrix', 'cursor'); -- не будет работает (так и должно быть)
--     FETCH ALL FROM "cursor";
-- END;


-- 12) Используя рекурсивное обобщенное табличное выражение, для каждой задачи вывести кол-во предшествующих ей задач

WITH RECURSIVE temp1(title, parenttask, path) AS (
    SELECT
        title,
        parenttask,
        cast( title as varchar (500)) as path,
        0 AS PrevCount
    FROM (VALUES
        ('C1_S21_BashUtils',NULL ,'C1_S21_BashUtils',0),
        ('СPP1_Matrix+','C5_S21_matrix','СPP1_Matrix+',0),
        ('L1_Linux','C2_S21_String+','L1_Linux',0),
        ('SQL1_Boot_camp','C5_S21_matrix','SQL1_Boot_camp',0)
        ) AS
        initial_values(title,parenttask,path, PrevCount)
    UNION
    SELECT
        t2.title,
        t2.parenttask,
        cast (temp1.path || '->' || t2.title  as varchar (500)),
        PrevCount + 1
    FROM
        tasks t2
    JOIN
        temp1  ON (temp1.title = t2.parenttask)
)
SELECT
  TITLE, PREVCOUNT
from
    temp1
WHERE path ~ ('C1_S21_BashUtils')
ORDER BY 1;

-- 13) Найти "удачные" для проверок дни. День считается "удачным", если в нем есть хотя бы N идущих подряд успешных проверки
DROP PROCEDURE IF EXISTS find_lucky_day CASCADE;
CREATE OR REPLACE PROCEDURE find_lucky_day(in cursor refcursor,
    target_count INT
) LANGUAGE plpgsql AS $$
BEGIN
OPEN cursor FOR
   WITH t1 AS (
       SELECT * FROM Checks
       JOIN p2p on checks.id = p2p."check"
       LEFT JOIN verter v on checks.id = v."check"
       JOIN tasks t on checks.task = t.title
       JOIN xp ON checks.id = xp."check"
       WHERE P2P.State = 'Success' AND v.State = 'Success'
       )
    SELECT Date
    FROM t1
    WHERE t1.xpamount >= t1.maxxp * 0.8
    GROUP BY Date
    HAVING COUNT(Date) >= target_count;
END;
$$;

-- BEGIN;
--     CALL find_lucky_day('cursor', 2);
--     FETCH ALL FROM "cursor";
-- END;


-- 14) Определить пира с наибольшим количеством XP
DROP PROCEDURE IF EXISTS find_max_xp CASCADE;
CREATE OR REPLACE PROCEDURE find_max_xp(in cursor refcursor)
LANGUAGE plpgsql AS $$
BEGIN
    OPEN cursor FOR
    SELECT Nickname AS Peer, SUM(XPAmount) as XP
    FROM Peers
    JOIN Checks c on Peers.nickname = c.peer
    JOIN xp x on c.id = x."check"
    GROUP BY Nickname
    ORDER BY XP DESC
    LIMIT 1;
END;
$$;

-- BEGIN;
--     CALL find_max_xp('cursor');
--     FETCH ALL FROM "cursor";
-- END;



-- 15) Определить пиров, приходивших раньше заданного временеи не менее N раз за все время
DROP PROCEDURE IF EXISTS find_peer_timeVisit CASCADE;
CREATE OR REPLACE PROCEDURE find_peer_timeVisit(IN cursor refcursor,
    target_time TIME,
    target_count INT
)LANGUAGE plpgsql AS $$
BEGIN
    OPEN cursor FOR
    SELECT Peer
    FROM Timetracking
    WHERE Timetracking.Time < target_time
    GROUP BY Peer
    HAVING COUNT(*) >= target_count
    ORDER BY Peer DESC;
END;
$$;
--
-- BEGIN;
--     CALL find_peer_timeVisit('cursor', '10:00:00', 1);
--     FETCH ALL IN "cursor";
-- END;



-- 16) Определить пиров, выходивших за последние N дней из кампуса больше M раз
DROP PROCEDURE IF EXISTS find_peer_exit CASCADE;
CREATE OR REPLACE PROCEDURE find_peer_exit(IN cursor refcursor,
    target_date INT,
    target_count INT
)LANGUAGE plpgsql AS $$
BEGIN
    OPEN cursor FOR
    SELECT Peer
    FROM (SELECT Peer, Date, count(*) AS counts
         FROM Timetracking
         WHERE Timetracking.Date > (current_date - target_date)
         GROUP BY Peer, Date) as t1
    GROUP BY Peer
    HAVING SUM(counts) > target_count;
END;
$$;

-- BEGIN;
--     CALL find_peer_exit('cursor', 88, 1);
--     FETCH ALL IN "cursor";
-- END;


-- 17) Определить для каждого месяца процент ранних входов
DROP PROCEDURE IF EXISTS percent_of_early_entries CASCADE;
CREATE OR REPLACE PROCEDURE percent_of_early_entries(inout cursor refcursor)
LANGUAGE plpgsql AS $$
BEGIN

OPEN cursor FOR
WITH  timetrack AS (  -- перевод дат в месяца
        SELECT id, peer, (SELECT to_char(timetracking.date, 'Month')) AS date, time, state FROM timetracking
    ),
     prs AS (
        SELECT nickname, (SELECT to_char(peers.birthday, 'Month')) AS date FROM peers
    ),
     all_time AS (
    SELECT timetrack.date, count(timetrack.date)
    FROM timetrack -- сколько раз люди, родившиеся в этот месяц, приходили в кампус за всё время
    JOIN prs ON timetrack.date = prs.date
    WHERE timetrack.state = '1'
    GROUP BY timetrack.date
    ),
    before_12 AS (
    SELECT timetrack.date, count(timetrack.state)  -- сколько раз люди, родившиеся в этот месяц, приходили в кампус за всё время до 12:00
    FROM timetrack
    JOIN prs ON timetrack.date = prs.date
    WHERE timetrack.state = '1' AND EXTRACT(HOUR FROM timetrack.time) < 12
    GROUP BY timetrack.date
    ),
    months AS (
    SELECT to_char(to_date(to_char(month_num, 'FM00'), 'MM'), 'Month') AS month  -- таблица со всеми месяцами
    FROM generate_series(1, 12) AS month_num
     )

    -- запрос, который выводит в одном столбце все месяцы, а вдругом каждому соответственно (before_12/all_time)*100
    SELECT months.month AS Month, COALESCE((before_12.count::float / all_time.count::float) * 100, 0) AS EarlyEntries FROM months
    FULL JOIN all_time ON all_time.date = months.month
    FULL JOIN before_12 ON before_12.date = months.month;
END;
$$;

BEGIN;
    CALL percent_of_early_entries('cursor');
    FETCH ALL FROM "cursor";
    CLOSE "cursor";
END;
