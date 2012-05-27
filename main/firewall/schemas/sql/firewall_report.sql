CREATE TABLE IF NOT EXISTS firewall_report (
    `date` DATE,
    event VARCHAR(16),
    source INT UNSIGNED,
    proto VARCHAR(16),
    dport INT,
    packets BIGINT
) ENGINE = MyISAM;
