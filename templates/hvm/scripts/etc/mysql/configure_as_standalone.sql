USE `mysql`;

DELETE
FROM `user`
WHERE `User` LIKE 'root';

DELETE
FROM `db`
WHERE `User` LIKE '';

GRANT
ALL PRIVILEGES
ON *.*
TO 'bmoorman'@'%' IDENTIFIED BY PASSWORD '%BMOORMAN_HASH%'
WITH GRANT OPTION;

GRANT
ALL PRIVILEGES
ON *.*
TO 'cplummer'@'%' IDENTIFIED BY PASSWORD '%CPLUMMER_HASH%'
WITH GRANT OPTION;

GRANT
ALL PRIVILEGES
ON *.*
TO 'ecall'@'10.%' IDENTIFIED BY PASSWORD '%ECALL_HASH%'
WITH GRANT OPTION;

GRANT
SELECT, PROCESS, REPLICATION CLIENT, TRIGGER, SHOW VIEW
ON *.*
TO 'jstubbs'@'10.%' IDENTIFIED BY PASSWORD '%JSTUBBS_HASH%';

GRANT
SELECT, INSERT, UPDATE, DELETE
ON *.*
TO 'tpurdy'@'%' IDENTIFIED BY PASSWORD '%TPURDY_HASH%';

GRANT
SELECT
ON *.*
TO 'npeterson'@'%' IDENTIFIED BY PASSWORD '%NPETERSON_HASH%';

GRANT
PROCESS, SUPER, REPLICATION CLIENT
ON *.*
TO 'monitoring'@'localhost' IDENTIFIED BY '%MONITORING_AUTH%';

GRANT
PROCESS
ON *.*
TO 'mytop'@'localhost' IDENTIFIED BY '%MYTOP_AUTH%';

FLUSH PRIVILEGES;

RESET MASTER;