CREATE TABLE IF NOT EXISTS radius_auth (
       timestamp TIMESTAMP,
       event VARCHAR(31),
       login VARCHAR(255),
       client VARCHAR(31),
       port INT,
       mac VARCHAR(31),
       INDEX(timestamp)
) ENGINE = MyISAM;
