CREATE TABLE events_report(
        date DATE,
        level  VARCHAR(6),
        source VARCHAR(256),
        nEvents  INT DEFAULT 0
);

GRANT USAGE, SELECT, UPDATE ON events_id_seq TO ebox;
