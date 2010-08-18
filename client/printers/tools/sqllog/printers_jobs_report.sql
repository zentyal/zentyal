CREATE TABLE printers_jobs_report(
         printer VARCHAR(255), 
         date DATE, 
         event VARCHAR(20),
         nJobs INT
        );
CREATE INDEX printers_jobs_report_date_i on printers_jobs_report(date);

