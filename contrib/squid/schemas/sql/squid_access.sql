CREATE TABLE IF NOT EXISTS squid_access (
       timestamp TIMESTAMP,
       elapsed INT,
       remotehost VARCHAR(255),
       code VARCHAR(255),
       bytes INT,
       method VARCHAR(10),
       url VARCHAR(1024),
       domain VARCHAR(255),
       rfc931 VARCHAR(255) DEFAULT '-',
       peer VARCHAR(255),
       mimetype VARCHAR(255),
       event VARCHAR(255),
       filterProfile VARCHAR(100),
       INDEX(timestamp)
) ENGINE = MyISAM;
