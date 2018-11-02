CREATE TABLE IF NOT EXISTS ebackup_storage_usage (
    timestamp TIMESTAMP,
    used BIGINT,
    available BIGINT,
    INDEX(timestamp)
) ENGINE = MyISAM;
