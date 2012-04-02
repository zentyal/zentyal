CREATE TABLE IF NOT EXISTS events_accummulated(
                      date TIMESTAMP NOT NULL,

                      source VARCHAR(256),

                      info INTEGER DEFAULT 0,
                      warn INTEGER DEFAULT 0,
                      error INTEGER DEFAULT 0,
                      fatal INTEGER DEFAULT 0
) ENGINE = MyISAM;
