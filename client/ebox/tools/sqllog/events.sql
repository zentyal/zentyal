CREATE TABLE events(
                      id SERIAL,

                      timestamp TIMESTAMP,
                      lastTimestamp  TIMESTAMP,
                      nRepeated      INTEGER DEFAULT 1,

                      level  VARCHAR(6),
                      source VARCHAR(20),
                      message VARCHAR(256)
);


GRANT USAGE, SELECT, UPDATE ON events_id_seq TO ebox;
