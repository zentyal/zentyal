CREATE TABLE mailfilter_smtp (
        timestamp TIMESTAMP NOT NULL,        
        
        event VARCHAR(255) NOT NULL,
        action VARCHAR(255) NOT NULL,    

        from_address VARCHAR(320) NOT NULL,
        to_address VARCHAR(320) NOT NULL,

        spam_hits FLOAT
);

CREATE INDEX mailfilter_smtp_timestamp_i on mailfilter_smtp(timestamp);
