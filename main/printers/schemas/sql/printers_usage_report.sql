CREATE TABLE printers_usage_report(
         `date` DATE,
         printer VARCHAR(255) NOT NULL,
         pages INT,
         users INT
);

CREATE INDEX printers_usage_report_job_i on printers_usage_report(`date`);
