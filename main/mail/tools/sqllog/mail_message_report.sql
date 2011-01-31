CREATE TABLE mail_message_report (
       date DATE,
       client_host_ip VARCHAR(16),
       user_from VARCHAR(255),
       domain_from VARCHAR(255),
       user_to VARCHAR(255),
       domain_to VARCHAR(255),
       event VARCHAR(255),
       message_type VARCHAR(10),
       status VARCHAR(25),
       bytes BIGINT,
       messages INT
);
