CREATE TABLE samba_quarantine (
    filename VARCHAR(120),
    qfilename VARCHAR(120),
    event VARCHAR(16),
    timestamp TIMESTAMP);
CREATE INDEX samba_quarantine_timestamp_i on samba_quarantine(timestamp);
