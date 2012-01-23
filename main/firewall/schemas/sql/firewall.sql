CREATE TABLE firewall(
    fw_in VARCHAR(16),
    fw_out VARCHAR(16),
    -- FIXME change CHAR(15) to INT UNSIGNED to emulate INET
    fw_src CHAR(15),
    fw_dst CHAR(15),
    fw_proto VARCHAR(16),
    fw_spt INT,
    fw_dpt INT,
    event VARCHAR(16),
    timestamp TIMESTAMP
);

CREATE INDEX firewall_timestamp_i on firewall(timestamp);
