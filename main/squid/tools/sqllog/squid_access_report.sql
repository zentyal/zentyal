CREATE TABLE squid_access_report (
       date DATE,
       ip VARCHAR(16),
       username VARCHAR(255),
       domain VARCHAR(255),
       event VARCHAR(10),
       code VARCHAR(32),
       bytes BIGINT,
       hits INT
);

CREATE OR REPLACE FUNCTION domain_from_url(url VARCHAR) RETURNS TEXT AS $$
DECLARE
    tmp VARCHAR;
    components VARCHAR[];
    domain VARCHAR;
    i INTEGER;
BEGIN
    tmp := url;
    tmp := regexp_replace(tmp,'http(s?)://','');
    tmp := regexp_replace(tmp,'(:|/).*','');
    components := regexp_split_to_array(tmp,E'\\.');

    domain := '';
    FOR i IN REVERSE array_upper(components,1)..1 LOOP
        IF domain = '' THEN
            domain := components[i];
        ELSE
            IF i > 1 or char_length(domain) < 8 THEN
                domain := components[i] || '.' || domain;
            END IF;
        END IF;
    END LOOP;

    RETURN domain;
END;
$$ LANGUAGE plpgsql;
