CREATE TABLE leases(interface CHAR(16), mac MACADDR, ip INET, timestamp TIMESTAMP, event VARCHAR(255));
CREATE INDEX leases_i on leases(timestamp);
