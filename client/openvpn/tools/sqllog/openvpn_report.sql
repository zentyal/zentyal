CREATE TABLE openvpn_report (
       date DATE,
       daemon_name VARCHAR(20),
       daemon_type VARCHAR(10),
       ip INET,
       certificate VARCHAR(100),
       connections INT
);
