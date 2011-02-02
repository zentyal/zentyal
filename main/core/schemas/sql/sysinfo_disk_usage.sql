CREATE TABLE sysinfo_disk_usage (
    timestamp TIMESTAMP,
    mountpoint VARCHAR(80),
    used BIGINT,
    free BIGINT
);

CREATE INDEX sysinfo_disk_usage_timestamp_i on sysinfo_disk_usage(timestamp);
