CREATE TABLE pop_proxy_filter (
        date TIMESTAMP NOT NULL,        

        address VARCHAR(320),
        clientConn VARCHAR(50) NOT NULL,        

        event VARCHAR(255) NOT NULL,

        mails       BIGINT DEFAULT 0,
        clean        BIGINT DEFAULT 0,               
        spam         BIGINT DEFAULT 0,
        virus     BIGINT DEFAULT 0
);

CREATE INDEX timestamp_i on pop_proxy_filter(date);
