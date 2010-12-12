CREATE TABLE ebackup_storage_usage (
    timestamp TIMESTAMP,
    used BIGINT,
    available BIGINT
);

CREATE INDEX ebackup_storage_usage_timestamp_i on ebackup_storage_usage(timestamp);
