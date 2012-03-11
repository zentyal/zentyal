CREATE TABLE IF NOT EXISTS samba_quarantine (
    filename VARCHAR(120),
    qfilename VARCHAR(120),
    event VARCHAR(16),
    timestamp TIMESTAMP,
    INDEX(timestamp)
);
