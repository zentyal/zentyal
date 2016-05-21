CREATE TABLE IF NOT EXISTS av_db_updates (
    timestamp TIMESTAMP,
    source VARCHAR(24),
    event VARCHAR(20),
    INDEX(timestamp)
) ENGINE = MyISAM;
