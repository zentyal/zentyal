CREATE TABLE IF NOT EXISTS audit_actions(
    timestamp   TIMESTAMP,
    username    VARCHAR(40),
    module      VARCHAR(40),
    event       ENUM('add', 'set', 'del', 'move', 'action'),
    model       VARCHAR(60),
    id          VARCHAR(120),
    value       TEXT,
    oldvalue    TEXT,
    temporal    BOOLEAN DEFAULT TRUE
) ENGINE = MyISAM;
