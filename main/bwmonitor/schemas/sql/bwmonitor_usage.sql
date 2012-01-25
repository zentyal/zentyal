CREATE TABLE bwmonitor_usage (
    client CHAR(15), -- FIXME INET
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

    timestamp TIMESTAMP);

CREATE INDEX bwmonitor_usage_timestamp_i on bwmonitor_usage(timestamp);
CREATE INDEX bwmonitor_usage_client_i on bwmonitor_usage(client);
CREATE INDEX bwmonitor_usage_username_i on bwmonitor_usage(username);

