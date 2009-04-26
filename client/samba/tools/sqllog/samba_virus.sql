CREATE TABLE samba_virus (
    client INET,
    virus VARCHAR(120),
    filename VARCHAR(120),
    event VARCHAR(16),
    timestamp TIMESTAMP);
CREATE INDEX samba_virus_i on samba_virus(timestamp);
