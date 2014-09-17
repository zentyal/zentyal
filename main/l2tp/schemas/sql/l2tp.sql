CREATE TABLE IF NOT EXISTS l2tp(
    timestamp TIMESTAMP,
    event VARCHAR(60) NOT NULL,
    tunnel VARCHAR(60) NOT NULL,
    INDEX(timestamp)
) ENGINE = MyISAM;
