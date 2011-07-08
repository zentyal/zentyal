CREATE TABLE bwmonitor_usage (
    client INET,
    username VARCHAR(255),
    interface     VARCHAR(30),

    /* internal traffic */
    intTotalRecv  INTEGER,
    intTotalSent  INTEGER,
    intTCP        INTEGER,
    intUDP        INTEGER,
    intICMP       INTEGER,

    /* external traffic */
    extTotalRecv  INTEGER,
    extTotalSent  INTEGER,
    extTCP        INTEGER,
    extUDP        INTEGER,
    extICMP       INTEGER,

    timestamp TIMESTAMP);

CREATE INDEX bwmonitor_usage_timestamp_i on bwmonitor_usage(timestamp);
CREATE INDEX bwmonitor_usage_client_i on bwmonitor_usage(client);
