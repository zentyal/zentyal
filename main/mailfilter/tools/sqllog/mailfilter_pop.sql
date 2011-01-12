CREATE TABLE mailfilter_pop (
        timestamp TIMESTAMP NOT NULL,        

        address VARCHAR(320),
        clientConn VARCHAR(50) NOT NULL,        

        event VARCHAR(255) NOT NULL,

        mails       BIGINT DEFAULT 0,
        clean        BIGINT DEFAULT 0,               
        spam         BIGINT DEFAULT 0,
        virus     BIGINT DEFAULT 0
);

CREATE INDEX mailfilter_pop_timestamp_i on mailfilter_pop(timestamp);
