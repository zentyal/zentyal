CREATE TABLE IF NOT EXISTS openvpn_report (
       `date` DATE,
       daemon_name VARCHAR(20),
       daemon_type VARCHAR(10),
       ip INT UNSIGNED,
       certificate VARCHAR(100),
       connections INT
) ENGINE = MyISAM;
