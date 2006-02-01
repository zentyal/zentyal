CREATE TABLE access(timestamp TIMESTAMP, elapsed INT, remotehost  CHAR(255), code CHAR(255), bytes INT, method CHAR(10), url CHAR(1024), rfc931 CHAR(255), peer CHAR(255), mimetype CHAR(255), event VARCHAR(255));
CREATE INDEX timestamp_i on access(timestamp);

