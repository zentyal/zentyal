CREATE TABLE IF NOT EXISTS printers_usage_report(
         `date` DATE,
         printer VARCHAR(255) NOT NULL,
         pages INT,
         users INT,
         INDEX(`date`)
) ENGINE = MyISAM;
