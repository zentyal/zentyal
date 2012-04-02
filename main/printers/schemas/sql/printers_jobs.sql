CREATE TABLE IF NOT EXISTS printers_jobs(
         timestamp TIMESTAMP,
         job INT,
         printer VARCHAR(255) NOT NULL,
         username VARCHAR(255) NOT NULL,
         event VARCHAR(20) NOT NULL,
         INDEX(timestamp)
) ENGINE = MyISAM;
