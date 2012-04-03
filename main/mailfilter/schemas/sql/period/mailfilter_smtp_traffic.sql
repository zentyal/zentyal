CREATE TABLE IF NOT EXISTS mailfilter_smtp_traffic (
        `date`       TIMESTAMP NOT NULL,
        clean        BIGINT DEFAULT 0,
        spam         BIGINT DEFAULT 0,
        banned       BIGINT DEFAULT 0,
        infected     BIGINT DEFAULT 0,
        bad_header   BIGINT DEFAULT 0,
        blacklisted  BIGINT DEFAULT 0,

        INDEX(`date`)
) ENGINE = MyISAM;
