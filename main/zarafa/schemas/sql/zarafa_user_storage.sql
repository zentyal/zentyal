CREATE TABLE IF NOT EXISTS zarafa_user_storage (
    timestamp TIMESTAMP NOT NULL,
    username VARCHAR(255),
    fullname VARCHAR(255),
    email    VARCHAR(255),
    soft_quota BIGINT,
    hard_quota BIGINT,
    size       BIGINT
) ENGINE = MyISAM;
