CREATE TABLE printers_jobs_report(
         printer VARCHAR(255) NOT NULL,
         `date` DATE,
         event VARCHAR(20) NOT NULL,
         nJobs INT
        );
CREATE INDEX printers_jobs_report_date_i on printers_jobs_report(`date`);

