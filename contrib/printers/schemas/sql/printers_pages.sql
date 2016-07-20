CREATE TABLE IF NOT EXISTS printers_pages(
         timestamp TIMESTAMP,
         job INT,
         printer VARCHAR(255) NOT NULL,
         pages INT,
         INDEX(timestamp)
) ENGINE = MyISAM;
