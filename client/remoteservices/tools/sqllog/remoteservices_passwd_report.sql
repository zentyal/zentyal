CREATE TYPE remoteservices_passwd_weakness AS ENUM ('weak', 'average');
CREATE TYPE remoteservices_passwd_from AS ENUM ( 'LDAP', 'system');

CREATE TABLE remoteservices_passwd_report (
    timestamp TIMESTAMP,
    username VARCHAR(256),
    level remoteservices_passwd_weakness,
    source  remoteservices_passwd_from,
    date DATE
);

CREATE INDEX remoteservices_passwd_report_timestamp_i on remoteservices_passwd_report(timestamp);
