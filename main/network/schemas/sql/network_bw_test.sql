CREATE TABLE IF NOT EXISTS network_bw_test (
    timestamp TIMESTAMP,
    bps_down BIGINT,
    INDEX(timestamp)
);
