CREATE TABLE IF NOT EXISTS events_report(
        date DATE,
        level  VARCHAR(6),
        source VARCHAR(256),
        nEvents  INT DEFAULT 0
);
