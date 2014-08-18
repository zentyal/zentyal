CREATE TABLE IF NOT EXISTS ips_rule_updates (
    timestamp TIMESTAMP,
    event VARCHAR(7),
    failure_reason VARCHAR(512),
    INDEX(timestamp)
) ENGINE = MyISAM;
