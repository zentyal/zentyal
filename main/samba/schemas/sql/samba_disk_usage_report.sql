CREATE TABLE IF NOT EXISTS samba_disk_usage_report (
    date DATE NOT NULL,
    share VARCHAR(24) NOT NULL,
    type VARCHAR(10) NOT NULL,
    size BIGINT DEFAULT 0
) ENGINE = MyISAM;
