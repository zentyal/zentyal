CREATE TABLE IF NOT EXISTS samba_access (
    client INT UNSIGNED,
    username VARCHAR(50),
    resource VARCHAR(240),
    event VARCHAR(16),
    timestamp TIMESTAMP,
    INDEX(timestamp)
) ENGINE = MyISAM;
