CREATE TABLE pop_proxy_filter_traffic (
        date TIMESTAMP NOT NULL,        
   
        mails       BIGINT DEFAULT 0,
        clean        BIGINT DEFAULT 0,               
        spam         BIGINT DEFAULT 0,
        virus     BIGINT DEFAULT 0
);

CREATE INDEX timestamp_i on pop_proxy_filter_traffic(date);
