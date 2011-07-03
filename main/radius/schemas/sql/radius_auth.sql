CREATE TABLE radius_auth (
       timestamp TIMESTAMP,
       event VARCHAR(31),
       login VARCHAR(255),
       client VARCHAR(31),
       port INT,
       mac VARCHAR(31)
);

CREATE INDEX radius_auth_timestamp_i on radius_auth(timestamp);
