CREATE TABLE firewall_report (
    date DATE,
    event VARCHAR(16),
    source CHAR(15), -- FIXME INET
    proto VARCHAR(16),
    dport INT,
    packets BIGINT
);
