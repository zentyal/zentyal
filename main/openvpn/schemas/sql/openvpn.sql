CREATE TABLE IF NOT EXISTS openvpn(timestamp TIMESTAMP,
	event VARCHAR(60) NOT NULL,
	daemon_name VARCHAR(20),
	daemon_type VARCHAR(10),
	from_ip     CHAR(15), -- FIXME INET
	from_cert   VARCHAR(100),
    INDEX(timestamp)
);
