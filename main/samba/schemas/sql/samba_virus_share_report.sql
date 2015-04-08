CREATE TABLE IF NOT EXISTS samba_virus_share_report (
    date DATE,
    share VARCHAR(24) NOT NULL,
    virus BIGINT
) ENGINE = MyISAM;
