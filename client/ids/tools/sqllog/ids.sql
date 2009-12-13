CREATE TABLE ids(priority INT, description VARCHAR(128), source VARCHAR(32),
                 dest VARCHAR(32), protocol VARCHAR(16), timestamp TIMESTAMP,
                 event VARCHAR(8));
CREATE INDEX ids_timestamp_i on ids(timestamp);
