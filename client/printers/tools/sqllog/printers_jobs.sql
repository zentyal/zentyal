CREATE TABLE printers_jobs(
         timestamp TIMESTAMP, 
         job INT, 
         printer VARCHAR(255), 
         username VARCHAR(255), 
         event VARCHAR(20)
        );
CREATE INDEX printers_jobs_timestamp_i on printers_jobs(timestamp);

