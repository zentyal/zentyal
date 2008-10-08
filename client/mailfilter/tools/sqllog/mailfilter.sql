CREATE TABLE message_filter (
        date TIMESTAMP NOT NULL,        
        
        event VARCHAR(255) NOT NULL,
        action VARCHAR(255) NOT NULL,    

        from_address VARCHAR(320) NOT NULL,
        to_address VARCHAR(320) NOT NULL,

        spam_hits FLOAT
);

CREATE INDEX timestamp_i on message_filter(date);
