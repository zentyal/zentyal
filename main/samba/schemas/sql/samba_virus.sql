CREATE TABLE IF NOT EXISTS samba_virus (
    client CHAR(15), -- FIXME INET
    virus VARCHAR(120),
    filename VARCHAR(120),
    event VARCHAR(16),
    timestamp TIMESTAMP,
    INDEX(timestamp)
);
