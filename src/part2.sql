-- 1) Написать процедуру добавления P2P проверки
DROP PROCEDURE IF EXISTS add_p2p_check CASCADE;
CREATE OR REPLACE PROCEDURE add_p2p_check(
    checked_peer VARCHAR,
    checking_peer VARCHAR,
    task_name VARCHAR,
    p2p_check check_status,
    "time" TIME
) AS $$
DECLARE
    check_id INT;
    last_status varchar;
BEGIN
    SELECT state INTO last_status
    FROM p2p
    WHERE checkingpeer = checking_peer
    ORDER BY id DESC
    LIMIT 1;
    IF p2p_check = 'Start' THEN
        IF last_status = 'Start' THEN
        RAISE EXCEPTION 'Последняя p2p проверка у % не завершена.', checking_peer;
        END IF;
       SELECT (MAX(id)+1) INTO check_id  FROM Checks;
        INSERT INTO Checks (id, Peer, Task, Date)
        VALUES (check_id, checked_peer, task_name, NOW());
    ELSE
            IF last_status <> 'Start' THEN
            RAISE EXCEPTION 'Последний статус не является "Start".';
            END IF;
        SELECT "check" INTO check_id
        FROM P2P
        WHERE P2P.checkingpeer = checking_peer AND state = 'Start'
        ORDER BY 1 DESC
        LIMIT 1;
            IF check_id <= (select max("check") from p2p where state <> 'Start') THEN
            RAISE EXCEPTION  'Запись в p2p с таким check_id уже есть';
            end if;
    END IF;
    INSERT INTO P2P(id, "check", CheckingPeer, State, Time)
    VALUES ((select (max(id)+1) from p2p), check_id, checking_peer, p2p_check, "time");
END;
$$ LANGUAGE plpgsql;



-- -- добавление новой проверки
-- CALL add_p2p_check('lynseypi', 'vickeycl' , 'C2_S21_String+', 'Start', '10:50:00');
-- -- ошибка т.к. проверка эти пиром еще не завершена
-- CALL add_p2p_check('lynseypi', 'vickeycl' , 'C2_S21_String+', 'Start', '10:50:00');
-- -- добавление результата проверки
-- CALL add_p2p_check('lynseypi', 'vickeycl' , 'C2_S21_String+', 'Success', '11:50:00');
-- SELECT * FROM Checks;
-- SELECT P2P.id, P2P.check AS check_ID, P2P.checkingpeer, P2P.state, P2P.time FROM P2P;
-- delete from p2p where "check" = 22;
-- delete from checks where id = 22;

-- 2) Написать процедуру добавления проверки Verter'ом
DROP PROCEDURE IF EXISTS add_verter_check CASCADE;
CREATE OR REPLACE PROCEDURE add_verter_check(
    peer_name VARCHAR,
    task_name VARCHAR,
    state_verter check_status,
    v_time time)
AS $$
DECLARE -- Определение и иницицализация
    check_id INT;
    last_status varchar;
BEGIN
    IF state_verter = 'Start' THEN
        SELECT "check" INTO check_id
        FROM (SELECT * FROM p2p WHERE state = 'Success') AS p
        JOIN checks  ch ON p."check" = ch.id
        WHERE ch.peer = peer_name  AND ch.task = task_name
        ORDER BY Time DESC
        LIMIT 1;
            IF check_id <= (select max("check") from verter) THEN
            RAISE EXCEPTION  'Запись в verter с таким id уже есть';
            end if;
    ELSE
        SELECT
        state INTO last_status
        FROM verter
        ORDER BY id DESC
        LIMIT 1;
            IF last_status <> 'Start' THEN
             -- Если последний статус не равен "Start", генерируем ошибку
            RAISE EXCEPTION 'Последний статус не является "Start".';
            END IF;
        SELECT "check" INTO check_id
        FROM verter v
        ORDER BY id DESC
        LIMIT 1;
    END IF;
    INSERT INTO verter(id,"check",state,Time)
    VALUES ((SELECT MAX(id) + 1 FROM verter), check_id, state_verter, v_time);
END;
$$ LANGUAGE plpgsql;
-- -- проверка, на существующий ранее старт
-- CALL add_verter_check('armorcoo','C2_S21_String+','Success','12:02');
-- -- проверка на null. не было такого check_id
-- CALL add_verter_check('vickeycl','C2_S21_String+','Start','12:01');
-- -- проверка вертером уже была
-- CALL add_verter_check('ganymedl','SQL1_Boot_camp','Start','12:01');
-- -- добавление записейстарт и success для незавершенной проверки
-- CALL add_verter_check('ganymedl','SQL2_Info21','Start','12:00');
-- CALL add_verter_check('ganymedl','SQL2_Info21','Success','12:01');
-- SELECT verter.id, verter.check AS check_ID, verter.state, verter.time FROM verter;


-- 3) Написать триггер: после добавления записи со статутом "начало" в таблицу P2P, изменить соответствующую запись в таблице TransferredPoints
DROP FUNCTION IF EXISTS fnc_trg_p2p_update_transferredpoints CASCADE;
CREATE OR REPLACE FUNCTION fnc_trg_p2p_update_transferredpoints()
RETURNS TRIGGER AS $$
DECLARE
    checked_peer_f VARCHAR;
BEGIN
        SELECT peer INTO checked_peer_f
        FROM checks
        WHERE id = NEW."check";

        UPDATE TransferredPoints
        SET PointsAmount = (PointsAmount + 1)
        WHERE CheckingPeer = NEW.checkingpeer AND CheckedPeer = checked_peer_f;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_p2p_into_transferredpoints
AFTER INSERT
ON p2p
FOR EACH ROW
WHEN ( NEW.state = 'Start' )
EXECUTE FUNCTION fnc_trg_p2p_update_transferredpoints();

-- -- демонстрация текущего и измененного количества переданных очков
-- Select * from transferredpoints where checkingpeer = 'vickeycl' AND checkedpeer = 'lynseypi';
-- CALL add_p2p_check('lynseypi', 'vickeycl' , 'C2_S21_String+', 'Start', '10:50:00');
-- delete from p2p where "check" = 22;
-- delete from checks where id = 22;


-- 4) Написать триггер: перед добавлением записи в таблицу XP, проверить корректность добавляемой записи
DROP FUNCTION IF EXISTS trigger_xp_check CASCADE;
CREATE OR REPLACE FUNCTION trigger_xp_check()
RETURNS TRIGGER AS $$
DECLARE
    max_xp INT := 0;
BEGIN
    -- Выбираем максимальное значение XPAmount для задачи, по которой добавляется новая запись в таблицу XP
    SELECT MaxXP INTO max_xp
    FROM Checks -- Присоединяем таблицу Checks
    JOIN Tasks ON Checks.task = tasks.title -- Присоединяем таблицу Tasks через внешний ключ
    JOIN P2P ON checks.id = P2P.check -- Присоединяем таблицу P2P через внешний ключ
    JOIN Verter ON checks.id = Verter.check -- Присоединяем таблицу Verter через внешний ключ
    WHERE P2P.State = 'Success' AND Verter.State = 'Success' AND new.check = Checks.id; -- Ограничения по P2P и Verter, а также по новой записи в таблице XP
    -- Если значение max_xp равно 0, значит для данной задачи не определено максимальное значение XPAmount
    -- и проверка не может быть выполнена
    IF max_xp = 0 THEN
        RAISE EXCEPTION 'Max XP is not defined for this task';
    END IF;
    -- Если значение XPAmount новой записи в таблице XP превышает максимально допустимое для данной задачи,
    -- то выбрасываем исключение
    IF new.XPAmount > max_xp THEN
        RAISE EXCEPTION 'XPAmount % exceeds the maximum allowed amount % for this task', new.XPAmount, max_xp;
    END IF;
    RETURN new;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trigger_xp_check
    BEFORE INSERT ON XP
    FOR EACH ROW -- Добавлено "FOR EACH ROW" для триггера, чтобы работал с каждой записью
    EXECUTE FUNCTION trigger_xp_check();

-- INSERT INTO XP("check", XPAmount)  -- эта штука не сработает потому что так и должно быть
-- VALUES (5, 251);
-- SELECT * FROM XP;