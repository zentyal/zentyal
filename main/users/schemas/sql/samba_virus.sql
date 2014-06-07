CREATE TABLE IF NOT EXISTS samba_virus (
    client INT UNSIGNED,
    username VARCHAR(24),
    virus VARCHAR(120),
    filename VARCHAR(120),
    event VARCHAR(16),
    timestamp TIMESTAMP,
    INDEX(timestamp)
) ENGINE = MyISAM;
