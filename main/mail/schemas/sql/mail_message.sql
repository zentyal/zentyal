CREATE TABLE IF NOT EXISTS mail_message (
        timestamp TIMESTAMP NOT NULL,
        qid VARCHAR(50),
        message_id VARCHAR(340),
        client_host_ip INT UNSIGNED NOT NULL,
        client_host_name VARCHAR(255) NOT NULL,
        from_address VARCHAR(320),
        to_address VARCHAR(320),
        message_size BIGINT,
        relay VARCHAR(320),
        message_type VARCHAR(10) NOT NULL,
        status VARCHAR(25),
        message TEXT,
        event VARCHAR(255) NOT NULL,
        INDEX(timestamp)
) ENGINE = MyISAM;
