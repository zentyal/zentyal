CREATE TABLE printers_jobs_by_user_report(
         username VARCHAR(255), 
         date DATE,
         event VARCHAR(20),
         nJobs INT
        ); 
CREATE INDEX printers_jobs_by_user_report_timestamp_i on printers_jobs__by_user_report(date);

