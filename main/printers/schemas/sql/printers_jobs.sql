CREATE TABLE printers_jobs(
         timestamp TIMESTAMP,
         job INT,
         printer VARCHAR(255) NOT NULL,
         username VARCHAR(255) NOT NULL,
         event VARCHAR(20) NOT NULL
        );

CREATE INDEX printers_jobs_timestamp_i on printers_jobs(timestamp);
