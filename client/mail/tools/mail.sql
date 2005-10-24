CREATE TABLE message (
        message_id VARCHAR(340),
        client_host_ip INET NOT NULL,
        client_host_name VARCHAR(255) NULL,
        from_address VARCHAR(320),
        to_address VARCHAR(320) NOT NULL,
        message_size BIGINT,
        relay VARCHAR(320),
        status VARCHAR(25) NOT NULL,
        message TEXT NOT NULL,
        postfix_date TIMESTAMP NOT NULL
);
