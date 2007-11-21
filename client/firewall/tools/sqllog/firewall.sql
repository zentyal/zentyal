CREATE TABLE firewall(fw_in VARCHAR(16),  fw_out VARCHAR(16), fw_src INET,
fw_dst INET, fw_proto VARCHAR(16), fw_spt INT, fw_dpt INT, event VARCHAR(16), timestamp TIMESTAMP);
CREATE INDEX firewall_i on firewall(timestamp);
