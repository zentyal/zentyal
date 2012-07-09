CREATE TABLE IF NOT EXISTS dns_domains (
    timestamp TIMESTAMP,
    domains INT,
    INDEX(timestamp)
) ENGINE = MyISAM;
