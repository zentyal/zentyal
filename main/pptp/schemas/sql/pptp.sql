CREATE TABLE IF NOT EXISTS pptp(
    timestamp TIMESTAMP,
    event VARCHAR(60) NOT NULL,
    from_ip     INT UNSIGNED,
    INDEX(timestamp)
) ENGINE = MyISAM;