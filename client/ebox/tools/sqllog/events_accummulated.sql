CREATE TABLE events_accummulated(
                      date TIMESTAMP NOT NULL, 

                      source VARCHAR(20),

                      info INTEGER DEFAULT 0,
                      warn INTEGER DEFAULT 0,
                      error INTEGER DEFAULT 0,
                      fatal INTEGER DEFAULT 0
);


