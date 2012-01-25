CREATE TABLE IF NOT EXISTS zarafa_user_storage_report (
    `date` DATE NOT NULL,
    username VARCHAR(255) NOT NULL,
    fullname VARCHAR(255) NOT NULL,
    email    VARCHAR(255) NOT NULL,
    soft_quota BIGINT DEFAULT 0,
    hard_quota BIGINT DEFAULT 0,
    size       BIGINT DEFAULT 0
);
