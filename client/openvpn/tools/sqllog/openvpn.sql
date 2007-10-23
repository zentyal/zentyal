CREATE TABLE openvpn( 	timestamp TIMESTAMP, 
	event VARCHAR(60) NOT NULL,
	daemon_name VARCHAR(20),
	daemon_type VARCHAR(10),
	from_ip     INET,
	from_cert     VARCHAR(100)
	);
CREATE INDEX timestamp_i on openvpn(timestamp);

