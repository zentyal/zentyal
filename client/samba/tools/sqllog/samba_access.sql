CREATE TABLE samba_access (
    client INET,
    username VARCHAR(24),
    resource VARCHAR(240),
    event VARCHAR(16),
    timestamp TIMESTAMP);
CREATE INDEX samba_access_i on samba_access(timestamp);
