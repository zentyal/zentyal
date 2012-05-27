CREATE TABLE IF NOT EXISTS ebackup_stats (
    timestamp TIMESTAMP,
    elapsed BIGINT,
    files_num INT,
    new_files_num INT,
    del_files_num INT,
    changed_files_num INT,
    size BIGINT,
    errors INT,
    type ENUM ('full', 'incremental'),
    INDEX(timestamp)
) ENGINE = MyISAM;
