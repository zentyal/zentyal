CREATE TABLE remoteservices_passwd_users (
    timestamp TIMESTAMP,
    nUsers INT
);

CREATE INDEX remoteservices_passwd_users_timestamp_i on remoteservices_passwd_users(timestamp);
