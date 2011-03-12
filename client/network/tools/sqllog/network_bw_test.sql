CREATE TABLE network_bw_test (
    timestamp TIMESTAMP,
    bps_down BIGINT
);

CREATE INDEX network_bw_test_timestamp_i ON network_bw_test(timestamp);
