CREATE TABLE IF NOT EXISTS leases(
    interface CHAR(16),
    mac CHAR(17), -- FIXME MACADDR (BIGINT + SELECT hex() ?)
    ip CHAR(15), -- FIXME INET
    timestamp TIMESTAMP,
    event VARCHAR(255),
    INDEX(timestamp)
);
