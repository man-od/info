DROP TABLE IF EXISTS "peers" CASCADE;
DROP TABLE IF EXISTS "tasks" CASCADE;
DROP TABLE IF EXISTS "checks" CASCADE;
DROP TABLE IF EXISTS "p2p" CASCADE;
DROP TABLE IF EXISTS "friends" CASCADE;
DROP TABLE IF EXISTS "recommendations" CASCADE;
DROP TABLE IF EXISTS "timetracking" CASCADE;
DROP TABLE IF EXISTS "verter" CASCADE;
DROP TABLE IF EXISTS "xp" CASCADE;
DROP TABLE IF EXISTS "transferredpoints" CASCADE;

CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');

CREATE TABLE Peers
(
    Nickname varchar not null primary key ,
    birthday date not null default current_date
);
INSERT INTO Peers(Nickname, birthday)
VALUES
('vickeycl','1994-10-06'),
('sherikac','2000-07-01'),
('lynseypi','1998-09-03'),
('armorcoo','2003-01-18'),
('ganymedl','1994-04-19'),
('satoporr','1983-08-15');

CREATE TABLE Tasks
(
    Title varchar not null primary key ,
    ParentTask varchar,
    MaxXP integer not null default 100
);
INSERT INTO Tasks(Title, ParentTask, MaxXp)
VALUES
('C1_S21_BashUtils', null , 250),
('C2_S21_String+','C1_S21_BashUtils', 500),
('C3_S21_Math','C2_S21_String+',300),
('C4_S21_Decimal','C2_S21_String+',350),
('C5_S21_matrix','C4_S21_Decimal',200),
('СPP1_Matrix+','C5_S21_matrix',300),
('СPP2_Containers','СPP1_Matrix+',350),
('СPP3_SmartCalc','СPP2_Containers',600),
('СPP4_3DViewer','СPP3_SmartCalc',750),
('СPP5_MLP','СPP4_3DViewer',700),
('L1_Linux','C2_S21_String+',300),
('L2_Network','L1_Linux',250),
('L3_Monitoring','L2_Network',350),
('SQL1_Boot_camp','C5_S21_matrix',1500),
('SQL2_Info21','SQL1_Boot_camp',500),
('SQL3_Retail_Analitycs','SQL2_Info21',600);

CREATE TABLE Checks
(
    ID serial PRIMARY KEY not null,
    Peer varchar not null references Peers(Nickname),
    Task varchar not null references Tasks(Title),
    Date date
--     constraint fk_checks_peer foreign key (Peer) references Peers(Nickname),
--     constraint fk_checks_task foreign key (Task) references Tasks(Title)
);
INSERT INTO Checks(Peer,Task,Date)
VALUES
('sherikac','C1_S21_BashUtils','2023-10-06'),
('lynseypi', 'C1_S21_BashUtils', '2023-03-05'),
('armorcoo', 'C1_S21_BashUtils', '2023-03-07'),
('ganymedl', 'C1_S21_BashUtils', '2023-03-09'),
('satoporr', 'C1_S21_BashUtils', '2023-03-11'),
('vickeycl', 'C1_S21_BashUtils', '2023-03-13'),
('lynseypi', 'C1_S21_BashUtils', '2023-03-14'),
('ganymedl', 'C1_S21_BashUtils', '2023-03-17'),
('sherikac', 'C2_S21_String+', '2023-03-17'),
('armorcoo', 'C2_S21_String+', '2023-03-17'),
('satoporr', 'C2_S21_String+', '2023-03-20'),
('lynseypi', 'C2_S21_String+', '2023-03-21'),
('vickeycl', 'C1_S21_BashUtils', '2023-03-21'),
('armorcoo', 'C2_S21_String+', '2023-03-29'),
('ganymedl', 'L1_Linux','2023-04-09'),
('armorcoo', 'L1_Linux','2023-04-10'),
('ganymedl', 'C3_S21_Math','2023-04-19'),
('ganymedl', 'C4_S21_Decimal', '2023-04-19'),
('ganymedl', 'C5_S21_matrix', '2023-04-30'),
('ganymedl', 'SQL1_Boot_camp', '2023-05-15'),
('ganymedl', 'SQL2_Info21', '2023-05-25');

CREATE TABLE P2P
(
    ID serial PRIMARY KEY,
    "check" int references Checks(id),
    CheckingPeer varchar references Peers(Nickname),
    State check_status,
    Time time
--     constraint fk_p2p_check foreign key (CheckID) references Checks(ID),
--     constraint fk_p2p_checkingpeer foreign key (CheckingPeer) references Peers(Nickname)

);

CREATE TABLE Verter
(
    ID bigint PRIMARY KEY not null,
    "check" int references Checks(ID) not null,
    State check_status,
    Time time
);


CREATE TABLE TransferredPoints
(
    ID bigint PRIMARY KEY,
    CheckingPeer varchar not null,
    CheckedPeer varchar not null,
    PointsAmount integer not null,
    constraint fk_transferredpoints_checkingpeer foreign key (CheckingPeer) references Peers(Nickname),
    constraint fk_transferredpoints_checkedpeer foreign key (CheckedPeer) references Peers(Nickname)
);

CREATE TABLE Friends
(
    ID bigint PRIMARY KEY,
    Peer1 varchar not null,
    Peer2 varchar not null,
    constraint fk_friends_peer1 foreign key (Peer1) references Peers(Nickname),
    constraint fk_friends_peer2 foreign key (Peer2) references Peers(Nickname)
);
INSERT INTO Friends(ID,Peer1,Peer2)
VALUES
(1, 'armorcoo', 'lynseypi'),
(2, 'vickeycl', 'lynseypi'),
(3, 'vickeycl', 'sherikac'),
(4, 'ganymedl', 'satoporr'),
(5, 'ganymedl', 'sherikac'),
(6, 'satoporr', 'armorcoo'),
(7, 'sherikac', 'lynseypi');


CREATE TABLE Recommendations
(
    ID integer not null primary key,
    Peer varchar not null,
    RecommendedPeer varchar,
    constraint fk_recommendations_peer foreign key (Peer) references Peers(Nickname)
);
INSERT INTO Recommendations(ID, Peer, RecommendedPeer)
VALUES
(1, 'vickeycl', 'sherikac'),
(2, 'sherikac', 'vickeycl'),
(3, 'lynseypi', 'sherikac'),
(4, 'satoporr', 'armorcoo'),
(5, 'ganymedl', 'lynseypi'),
(6, 'armorcoo', 'sherikac'),
(7, 'vickeycl', 'lynseypi'),
(8, 'sherikac', 'ganymedl'),
(9, 'lynseypi', 'vickeycl'),
(10, 'satoporr', 'ganymedl'),
(11, 'ganymedl', 'armorcoo'),
(12, 'armorcoo', 'lynseypi'),
(13, 'armorcoo', 'ganymedl'),
(14, 'ganymedl', 'vickeycl'),
(15, 'ganymedl', 'satoporr'),
(16, 'ganymedl', 'sherikac');


CREATE TABLE XP
(
    ID serial not null PRIMARY KEY,
    "check" integer not null references Checks(ID),
    XPAmount integer not null check (XPAmount > 0)
);
INSERT INTO XP("check", XPAmount)
VALUES
(1,250),
(3,230),
(5,250),
(8,250),
(10,500),
(12,500),
(13,250),
(14,480),
(15,300),
(16,300),
(17,300),
(18,350),
(19,200),
(20,1450),
(21,500);

CREATE TABLE TimeTracking
(
    ID serial PRIMARY KEY,
    Peer varchar not null,
    Date date not null default current_date,
    Time time,
    State integer check (State in (1,2)),
    constraint fk_timetracking_peer foreign key (Peer) references Peers(Nickname)
);
INSERT INTO TimeTracking(ID, Peer, Date, Time, State)
VALUES
(1,'vickeycl','2023-10-06', '08:00', 1),
(2,'sherikac', '2023-03-05', '08:30', 1),
(3,'lynseypi', '2023-03-05', '09:00', 1),
(4,'vickeycl', '2023-03-05', '10:30', 2),
(5,'sherikac', '2023-03-05', '11:45', 2),
(6,'lynseypi', '2023-03-05', '13:00', 2),
(7,'lynseypi', '2023-03-07', '12:00', 1),
(8,'armorcoo', '2023-03-07', '12:30', 1),
(9,'lynseypi', '2023-03-07', '16:45', 2),
(10,'armorcoo', '2023-03-07', '17:30', 2),
(11,'armorcoo', '2023-03-09', '11:30', 1),
(12,'ganymedl', '2023-03-09', '13:20', 1),
(13,'armorcoo', '2023-03-09', '15:50', 2),
(14,'ganymedl', '2023-03-09', '16:20', 2),
(15,'satoporr', '2023-03-11', '10:00', 1),
(16,'ganymedl', '2023-03-11', '12:20', 1),
(17,'ganymedl', '2023-03-11', '17:50', 2),
(18,'satoporr', '2023-03-11', '18:00', 2),
(19,'satoporr', '2023-03-13', '12:00', 1),
(20,'vickeycl', '2023-03-13', '17:30', 1),
(21,'vickeycl', '2023-03-13', '19:30', 2),
(22,'satoporr', '2023-03-13', '20:45', 2),
(23,'lynseypi', '2023-03-14', '09:15', 1),
(24,'vickeycl', '2023-03-14', '10:20', 1),
(25,'vickeycl', '2023-03-14', '14:45', 2),
(26,'lynseypi', '2023-03-14', '16:15', 2),
(27,'lynseypi', '2023-03-17', '08:15', 1),
(28,'ganymedl', '2023-03-17', '08:16', 1),
(29,'lynseypi', '2023-03-17', '10:30', 2),
(30,'ganymedl', '2023-03-17', '11:21', 2),
(31,'sherikac', '2023-03-17', '11:30', 1),
(32,'ganymedl', '2023-03-17', '11:45', 1),
(33,'ganymedl', '2023-03-17', '12:20', 2),
(34,'sherikac', '2023-03-17', '12:30', 2),
(35,'sherikac', '2023-03-17', '12:50', 1),
(36,'armorcoo', '2023-03-17', '12:55', 1),
(37,'armorcoo', '2023-03-17', '14:15', 2),
(38,'sherikac', '2023-03-17', '18:45', 2),
(39,'satoporr', '2023-03-20', '11:20', 1),
(40,'armorcoo', '2023-03-20', '13:15', 1),
(41,'armorcoo', '2023-03-20', '18:20', 2),
(42,'satoporr', '2023-03-20', '19:20', 2),
(43,'satoporr', '2023-03-21', '08:20', 1),
(44,'vickeycl', '2023-03-21', '09:30', 1),
(45,'vickeycl', '2023-03-21', '15:15', 2),
(46,'satoporr', '2023-03-21', '19:20', 2),
(47, 'armorcoo','2023-03-29', '10:50', 1),
(48, 'ganymedl','2023-03-29', '10:55', 1),
(49, 'ganymedl','2023-03-29', '12:55', 2),
(50, 'armorcoo','2023-03-29', '13:55', 2),
(51, 'vickeycl', '2023-04-09', '09:00', 1),
(52, 'ganymedl', '2023-04-09', '09:05', 1),
(53, 'vickeycl', '2023-04-09', '11:45',2),
(54, 'ganymedl', '2023-04-09', '19:00',2),
(55, 'satoporr', '2023-04-10', '09:00',1),
(56, 'ganymedl', '2023-04-10', '09:05',1),
(57, 'satoporr', '2023-04-10', '11:45',2),
(58, 'satoporr', '2023-04-10', '19:00',2),
(59, 'lynseypi', '2023-04-19', '09:00',1),
(63, 'sherikac',  '2023-04-19', '09:01',1),
(60, 'ganymedl', '2023-04-19', '09:05',1),
(61, 'lynseypi', '2023-04-19', '11:45',2),
(65, 'sherikac',  '2023-04-19', '12:45',2),
(66, 'ganymedl',  '2023-04-19', '19:00',2),
(67, 'armorcoo',  '2023-04-30', '09:00',1),
(68, 'ganymedl',  '2023-04-30', '09:05',1),
(69, 'armorcoo',  '2023-04-30', '11:45',2),
(70, 'ganymedl',  '2023-04-30', '19:00',2),
(71, 'satoporr',  '2023-05-15', '09:00',1),
(72, 'ganymedl',  '2023-05-15', '09:05',1),
(73, 'satoporr',  '2023-05-15', '11:45',2),
(74, 'ganymedl',  '2023-05-15', '19:05',2),
(75, 'armorcoo',  '2023-05-25', '09:00',1),
(76, 'ganymedl',  '2023-05-25', '09:05',1),
(77, 'armorcoo',  '2023-05-25', '14:45',2),
(78, 'ganymedl',  '2023-05-25', '09:00',2),
(79, 'sherikac', '2023-07-01', '11:30', 1),
(80, 'sherikac', '2023-07-01', '14:30', 2),
(81, 'sherikac', '2023-07-01', '15:30', 1);


CREATE OR REPLACE PROCEDURE ImportExportTablesData(tableName text, filePath text, action text) AS $$
BEGIN
    IF action = 'import' THEN
        EXECUTE 'COPY ' || tableName || ' FROM ''' || filePath || ''' WITH (FORMAT CSV, HEADER, DELIMITER '','')';
    ELSIF action = 'export' THEN
        EXECUTE 'COPY (SELECT * FROM ' || tableName || ') TO ''' || filePath || ''' WITH (FORMAT CSV, HEADER, DELIMITER '','')';
    ELSE
        RAISE EXCEPTION 'Invalid action specified. Valid actions are ''import'' and ''export''.';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- пример вызова export в CSV
-- CALL ImportExportTablesData('XP', '/Users/vickeycl/SQL/suki/src/CSV/transferredpoints.csv', 'export');
-- CALL ImportExportTablesData('transferredpoints', '/Users/vickeycl/SQL/suki/src/CSV/transferredpoints.csv', 'import');
-- CALL ImportExportTablesData('verter', '/Users/vickeycl/SQL/suki/src/CSV/verter.csv', 'import');
-- CALL ImportExportTablesData('p2p', '/Users/vickeycl/SQL/suki/src/CSV/p2p.csv', 'import');



