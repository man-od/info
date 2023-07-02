-- 1) Создать хранимую процедуру, которая, не уничтожая базу данных, уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.
CREATE OR REPLACE PROCEDURE drop_tablename_tables(tables_name varchar)
LANGUAGE plpgsql
AS $$
DECLARE
    table_name varchar;
BEGIN
    -- проходимся циклом по всем значениям в таблице с названиями таблиц и отбираем несистемные и начинающиеся с tables_name
 FOR table_name IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE concat(tables_name, '%')) LOOP
    EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(table_name) || ' CASCADE';  -- удаляем, quote_ident для нормальной вставки переменной в команду
    END LOOP;
END;
$$;

CREATE TABLE proverka();
BEGIN;
 CALL drop_tablename_tables('t');
END;


-- 2) Создать хранимую процедуру с выходным параметром, которая выводит список имен и параметров всех скалярных SQL функций пользователя в текущей базе данных.
-- Имена функций без параметров не выводить. Имена и список параметров должны выводиться в одну строку. Выходной параметр возвращает количество найденных функций.
CREATE OR REPLACE PROCEDURE count_of_scal_functions(out counter bigint)
LANGUAGE plpgsql
AS $$
    DECLARE
        result_text text;  -- для записи найденных функций
BEGIN
    CREATE TEMPORARY TABLE functions AS (  -- названия функций
        SELECT concat(proname, ' | ', tn.typname) as output
        FROM pg_proc -- таблица с функциями
                 JOIN (SELECT oid
                       FROM pg_roles -- таблица с пользователями
                       WHERE rolsuper IS true   -- выводим только текущего полльзователя
                         AND
                           rolcanlogin IS true
                         AND rolreplication IS false
                         AND rolbypassrls IS false) AS role
                      ON role.oid = pg_proc.proowner
                 JOIN (SELECT typname, oid FROM pg_type) AS tn ON tn.oid = pg_proc.prorettype -- название входного параметра
        WHERE prorettype::varchar ~ '^[0-9]+$'
          AND tn.typname NOT LIKE 'void'
          AND proargtypes::varchar ~ '^[0-9]+$' -- скалярная функция - одно входное значение и одно выходное
    );

    SELECT COUNT(functions.output) INTO counter FROM functions;  -- запись выходного значения

    SELECT array_to_string(array_agg(output), E'\n') INTO result_text FROM functions;  -- запись результата functions в однострочный массив
    RAISE NOTICE 'Функции: %', result_text::text;  -- вывод массива
END
$$;

-- DO $$
--     DECLARE
--         count_result bigint;
--     BEGIN
--         CALL count_of_scal_functions(count_result);
--         RAISE NOTICE 'Результат процедуры: %', count_result;
--     END;
-- $$;


-- 3) Создать хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных.
-- Выходной параметр возвращает количество уничтоженных триггеров.
CREATE OR REPLACE PROCEDURE drop_dml_triggers(out counter bigint)
LANGUAGE plpgsql
AS $$
    DECLARE
        name_of_trigger varchar;  -- название триггерной функции
        name_of_table varchar;  -- название таблицы, привязанной к триггеру
BEGIN
        counter := 0;
        RAISE NOTICE 'Удалённые триггеры:';
    FOR name_of_trigger, name_of_table IN (SELECT tgname, pgc.relname  FROM pg_trigger  -- таблица триггеров
                            JOIN (SELECT oid, relname FROM pg_class) AS pgc  -- таблица с названиями таблиц
                            ON pg_trigger.tgrelid = pgc.oid
                            WHERE tgisinternal IS false) LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident(name_of_trigger) || ' ON ' || quote_ident(name_of_table) || ' CASCADE';
        RAISE NOTICE '%', name_of_trigger::text;
        counter := counter + 1;
    END LOOP;
    RAISE NOTICE 'Количество удалённых триггеров: %', counter::text;
END;
$$;

-- DO $$
--     DECLARE
--         count_result bigint;
--     BEGIN
--         CALL drop_dml_triggers(count_result);
--     END;
-- $$;

-- 4) Создать хранимую процедуру с входным параметром, которая выводит имена и описания типа объектов (только хранимых процедур и скалярных функций),
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.

CREATE OR REPLACE PROCEDURE name_and_discript_of_objects(in substroke varchar, INOUT result_cursor refcursor)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN result_cursor FOR                                              -- Открытие курсора и запись туда временной таблицы
        SELECT proname, pg_description.description                      -- вывод названия функции и описания
        FROM pg_proc                                                    -- таблица с функциями
        LEFT JOIN pg_description ON pg_proc.oid = pg_description.objoid
        WHERE ((prorettype::varchar ~ '^[0-9]+$'AND                     -- либо скалярная функция
        proargtypes::varchar ~ '^[0-9]+$' AND
        prokind =  'f') OR prokind = 'p') AND                           -- либо процедура
        prosrc LIKE '%' || substroke || '%';
END;
$$;

-- BEGIN;
--     CALL name_and_discript_of_objects('SELECT', 'cursor');
--     FETCH ALL FROM "cursor";
--     CLOSE "cursor";
-- END

