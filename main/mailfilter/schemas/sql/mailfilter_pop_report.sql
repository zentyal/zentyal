CREATE TABLE mailfilter_pop_report (
        date DATE NOT NULL,
        event VARCHAR(255) NOT NULL,
        address VARCHAR(320),
        clientConn VARCHAR(50) NOT NULL,
        clean     BIGINT DEFAULT 0,
        spam      BIGINT DEFAULT 0,
        virus     BIGINT DEFAULT 0
);
