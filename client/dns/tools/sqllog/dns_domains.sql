CREATE TABLE dns_domains (
    timestamp TIMESTAMP,
    domains INT
);

CREATE INDEX dns_domains_timestamp_i on dns_domains(timestamp);
