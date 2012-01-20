CREATE TABLE ebackup_stats (
    timestamp TIMESTAMP,
    elapsed BIGINT,
    files_num INT,
    new_files_num INT,
    del_files_num INT,
    changed_files_num INT,
    size BIGINT,
    errors INT,
    type ENUM ('full', 'incremental')
);

CREATE INDEX ebackup_stats_timestamp_i on ebackup_stats(timestamp);
