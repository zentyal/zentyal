CREATE TABLE IF NOT EXISTS events(
                      id SERIAL,

                      timestamp TIMESTAMP,
                      lastTimestamp  TIMESTAMP,
                      nRepeated      INTEGER DEFAULT 1,

                      level  VARCHAR(6),
                      source VARCHAR(256),
                      message VARCHAR(256)
);
