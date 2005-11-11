CREATE TABLE message (
        message_id VARCHAR(340),
        client_host_ip INET NOT NULL,
        client_host_name VARCHAR(255) NOT NULL,
        from_address VARCHAR(320),
        to_address VARCHAR(320),
        message_size BIGINT,
        relay VARCHAR(320),
        status VARCHAR(25) NOT NULL,
        message TEXT,
        postfix_date TIMESTAMP NOT NULL,
		  event VARCHAR(255) NOT NULL
);
