CREATE TABLE IF NOT EXISTS ips_event(
    priority INT,
    description VARCHAR(128),
    source VARCHAR(32),
    dest VARCHAR(32),
    protocol VARCHAR(16),
    timestamp TIMESTAMP,
    event VARCHAR(8),
    INDEX(timestamp)
) ENGINE = MyISAM;
