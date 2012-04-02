CREATE TABLE IF NOT EXISTS openvpn(
    timestamp TIMESTAMP,
	event VARCHAR(60) NOT NULL,
	daemon_name VARCHAR(20),
	daemon_type VARCHAR(10),
	from_ip     INT UNSIGNED,
	from_cert   VARCHAR(100),
    INDEX(timestamp)
) ENGINE = MyISAM;
