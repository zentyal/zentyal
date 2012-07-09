CREATE TABLE IF NOT EXISTS audit_sessions(
    timestamp   TIMESTAMP,
    username    VARCHAR(40),
    ip          INT UNSIGNED,
    event       ENUM('login', 'logout', 'fail', 'expired')
) ENGINE = MyISAM;
