CREATE TABLE IF NOT EXISTS ipsec(
    timestamp TIMESTAMP,
    event VARCHAR(60) NOT NULL,
    tunnel VARCHAR(60) NOT NULL,
    INDEX(timestamp)
) ENGINE = MyISAM;