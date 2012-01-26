CREATE TABLE IF NOT EXISTS sysinfo_disk_usage (
    `timestamp` TIMESTAMP,
    mountpoint VARCHAR(80),
    used BIGINT,
    free BIGINT,
    INDEX(timestamp)
);
