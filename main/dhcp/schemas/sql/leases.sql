CREATE TABLE IF NOT EXISTS leases(
    interface CHAR(16),
    mac BINARY(6),
    ip INT UNSIGNED,
    timestamp TIMESTAMP,
    event VARCHAR(255),
    INDEX(timestamp)
) ENGINE = MyISAM;
