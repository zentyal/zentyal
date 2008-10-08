CREATE TABLE mailfilter_traffic (
        date         TIMESTAMP NOT NULL,       
        clean        BIGINT DEFAULT 0,               
        spam         BIGINT DEFAULT 0,
        banned       BIGINT DEFAULT 0,
        infected     BIGINT DEFAULT 0,
        bad_header   BIGINT DEFAULT 0,
        blacklisted  BIGINT DEFAULT 0
);

CREATE INDEX timestamp_i on mailfilter_traffic(date);
