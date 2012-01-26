CREATE TABLE IF NOT EXISTS printers_jobs_by_user_report(
    username VARCHAR(255) NOT NULL,
    `date` DATE,
    event VARCHAR(20) NOT NULL,
    nJobs INT,
    INDEX(`date`)
);
