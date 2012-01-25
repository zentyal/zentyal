CREATE TABLE remoteservices_passwd_report (
    timestamp TIMESTAMP,
    username VARCHAR(256),
    level ENUM ('weak', 'average'),
    source ENUM ('LDAP', 'system'),
    `date` DATE
);

CREATE INDEX remoteservices_passwd_report_timestamp_i on remoteservices_passwd_report(timestamp);
