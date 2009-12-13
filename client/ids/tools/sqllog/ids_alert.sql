CREATE TABLE ids_alert(date TIMESTAMP NOT NULL, alert BIGINT DEFAULT 0);

CREATE INDEX ids_alert_date_i on ids_alert(date);
