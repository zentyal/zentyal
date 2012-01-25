CREATE TABLE bwmonitor_usage_report (
    client CHAR(15), -- FIXME INET
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

    `date` DATE);

CREATE INDEX bwmonitor_usage_report_date_i on bwmonitor_usage_report(`date`);
CREATE INDEX bwmonitor_usage_report_client_i on bwmonitor_usage_report(client);
CREATE INDEX bwmonitor_usage_report_username_i on bwmonitor_usage_report(username);

