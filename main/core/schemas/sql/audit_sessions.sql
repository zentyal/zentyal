CREATE TABLE audit_sessions(
    timestamp   TIMESTAMP,
    username    VARCHAR(40),
--    ip          INT UNSIGNED,
--  FIXME: use int once the framework is ready to work with INET_NTOA and INET_ATON
--         the CHAR type is a quick and dirty workaround
    ip          CHAR(15),
    event       ENUM('login', 'logout', 'fail', 'expired')
);
