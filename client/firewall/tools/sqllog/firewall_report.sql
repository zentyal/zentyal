CREATE TABLE firewall_report (
    date DATE,
    event VARCHAR(16),
    source INET,
    proto VARCHAR(16),
    dport INT,
    packets BIGINT
);
