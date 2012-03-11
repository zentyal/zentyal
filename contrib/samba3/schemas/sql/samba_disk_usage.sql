CREATE TABLE IF NOT EXISTS samba_disk_usage (
    timestamp TIMESTAMP NOT NULL,
    share VARCHAR(24) NOT NULL,
    type VARCHAR(10) NOT NULL,
    size INT DEFAULT 0
);
