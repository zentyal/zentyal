CREATE TABLE mailfilter_pop_traffic (
        date TIMESTAMP NOT NULL,        
   
        mails       BIGINT DEFAULT 0,
        clean        BIGINT DEFAULT 0,               
        spam         BIGINT DEFAULT 0,
        virus     BIGINT DEFAULT 0
);

CREATE INDEX mailfilter_pop_traffic_date_i on mailfilter_pop_traffic(date);
