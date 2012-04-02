CREATE TABLE IF NOT EXISTS firewall(
    fw_in VARCHAR(16),
    fw_out VARCHAR(16),
    fw_src INT UNSIGNED,
    fw_dst INT UNSIGNED,
    fw_proto VARCHAR(16),
    fw_spt INT,
    fw_dpt INT,
    event VARCHAR(16),
    timestamp TIMESTAMP,
    INDEX(timestamp)
) ENGINE = MyISAM;
