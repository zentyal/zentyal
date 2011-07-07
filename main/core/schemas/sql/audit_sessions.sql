CREATE TYPE audit_session_event AS ENUM('login', 'logout', 'fail', 'expired');

CREATE TABLE audit_sessions(
    timestamp   TIMESTAMP,
    username    VARCHAR(40),
    ip          inet,
    event       audit_session_event
);
