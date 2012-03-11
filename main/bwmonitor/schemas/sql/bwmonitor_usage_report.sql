CREATE TABLE IF NOT EXISTS bwmonitor_usage_report (
    client INT UNSIGNED,
    username VARCHAR(255),

    /* internal traffic */
    intTotalRecv  BIGINT,
    intTotalSent  BIGINT,
    intTCP        BIGINT,
    intUDP        BIGINT,
    intICMP       BIGINT,

    /* external traffic */
    extTotalRecv  BIGINT,
    extTotalSent  BIGINT,
    extTCP        BIGINT,
    extUDP        BIGINT,
    extICMP       BIGINT,

    `date` DATE,

    INDEX (`date`), INDEX(client), INDEX(username)
);
