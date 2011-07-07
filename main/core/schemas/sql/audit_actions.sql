CREATE TYPE audit_event AS ENUM('add', 'set', 'del', 'move', 'action');

CREATE TABLE audit_actions(
    timestamp   TIMESTAMP,
    username    VARCHAR(40),
    module      VARCHAR(40),
    event       audit_event,
    model       VARCHAR(40),
    id          VARCHAR(40),
    value       TEXT,
    oldvalue    TEXT,
    temporal    BOOLEAN DEFAULT TRUE
);
