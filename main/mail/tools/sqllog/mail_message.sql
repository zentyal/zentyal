CREATE TABLE mail_message (
        timestamp TIMESTAMP NOT NULL,
        qid VARCHAR(50),
        message_id VARCHAR(340),
        client_host_ip INET NOT NULL,
        client_host_name VARCHAR(255) NOT NULL,
        from_address VARCHAR(320),
        to_address VARCHAR(320),
        message_size BIGINT,
        relay VARCHAR(320),
        message_type VARCHAR(10) NOT NULL,
        status VARCHAR(25) NOT NULL,
        message TEXT,
        event VARCHAR(255) NOT NULL
);
CREATE INDEX mail_message_timestamp_i ON mail_message(timestamp);
