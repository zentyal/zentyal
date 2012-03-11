CREATE TABLE IF NOT EXISTS ids_report (
    date DATE,
    source VARCHAR(32),
    priority1 BIGINT DEFAULT 0,
    priority2 BIGINT DEFAULT 0,
    priority3 BIGINT DEFAULT 0,
    priority4 BIGINT DEFAULT 0,
    priority5 BIGINT DEFAULT 0
);
