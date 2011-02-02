CREATE TABLE firewall_packet_traffic(
        date TIMESTAMP NOT NULL,
        drop BIGINT DEFAULT 0
);

CREATE INDEX firewall_packet_traffic_date_i on firewall_packet_traffic(date);
