CREATE TABLE IF NOT EXISTS samba_virus_report (
    `date` DATE,
    client INT UNSIGNED,
    virus BIGINT
) ENGINE = MyISAM;
