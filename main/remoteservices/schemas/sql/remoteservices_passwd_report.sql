CREATE TABLE IF NOT EXISTS remoteservices_passwd_report (
    timestamp TIMESTAMP,
    username VARCHAR(256),
    level ENUM ('weak', 'average'),
    source ENUM ('LDAP', 'system'),
    fullname VARCHAR(512),
    email VARCHAR(512),
    INDEX(timestamp)
) ENGINE = MyISAM;
