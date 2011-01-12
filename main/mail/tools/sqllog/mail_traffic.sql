CREATE TABLE mail_traffic (
       date TIMESTAMP NOT NULL,

       vdomain VARCHAR(300),
       sent BIGINT DEFAULT 0,
       received BIGINT DEFAULT 0,
       rejected BIGINT DEFAULT 0
);