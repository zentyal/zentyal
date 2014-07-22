CREATE TABLE IF NOT EXISTS bwmonitor_usage (
    client INT UNSIGNED,
    username VARCHAR(255),
    interface     VARCHAR(30),

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

    timestamp TIMESTAMP,

    INDEX(timestamp), INDEX(client), INDEX(username)
) ENGINE = MyISAM;
