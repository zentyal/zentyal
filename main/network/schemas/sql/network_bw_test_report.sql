CREATE TABLE IF NOT EXISTS network_bw_test_report (
    date DATE,
    maximum_down BIGINT,
    minimum_down BIGINT,
    mean_down BIGINT
) ENGINE = MyISAM;
