CREATE TABLE IF NOT EXISTS samba_quarantine (
    client INT UNSIGNED,
    username VARCHAR(24),
    filename VARCHAR(120),
    qfilename VARCHAR(120),
    event VARCHAR(16),
    timestamp TIMESTAMP,
    INDEX(timestamp)
) ENGINE = MyISAM;
