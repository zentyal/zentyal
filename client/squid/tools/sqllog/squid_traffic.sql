CREATE TABLE squid_traffic (
        date TIMESTAMP, 

         rfc931 CHAR(255) DEFAULT '-',

        requests BIGINT DEFAULT 0,

        accepted BIGINT DEFAULT 0,
        accepted_size BIGINT DEFAULT 0,

        denied   BIGINT DEFAULT 0,
        denied_size BIGINT DEFAULT 0,

        filtered BIGINT DEFAULT 0,
        filtered_size BIGINT DEFAULT 0
);

CREATE INDEX date on squid_traffic(timestamp);

