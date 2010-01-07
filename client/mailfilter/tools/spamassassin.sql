
create database spamassassin;
create language plpgsql;
create user amavis; 

CREATE TABLE bayes_expire (
  id integer NOT NULL default '0',
  runtime integer NOT NULL default '0'
) WITHOUT OIDS;

CREATE INDEX bayes_expire_idx1 ON bayes_expire (id);

CREATE TABLE bayes_global_vars (
  variable varchar(30) NOT NULL default '',
  value varchar(200) NOT NULL default '',
  PRIMARY KEY  (variable)
) WITHOUT OIDS;

INSERT INTO bayes_global_vars VALUES ('VERSION','3');

CREATE TABLE bayes_seen (
  id integer NOT NULL default '0',
  msgid varchar(200) NOT NULL default '',
  flag character(1) NOT NULL default '',
  PRIMARY KEY  (id,msgid)
) WITHOUT OIDS;

CREATE TABLE bayes_token (
  id integer NOT NULL default '0',
  token bytea NOT NULL default '',
  spam_count integer NOT NULL default '0',
  ham_count integer NOT NULL default '0',
  atime integer NOT NULL default '0',
  PRIMARY KEY  (id,token)
) WITHOUT OIDS;

CREATE INDEX bayes_token_idx1 ON bayes_token (token);

CREATE TABLE bayes_vars (
  id serial NOT NULL,
  username varchar(200) NOT NULL default '',
  spam_count integer NOT NULL default '0',
  ham_count integer NOT NULL default '0',
  token_count integer NOT NULL default '0',
  last_expire integer NOT NULL default '0',
  last_atime_delta integer NOT NULL default '0',
  last_expire_reduce integer NOT NULL default '0',
  oldest_token_age integer NOT NULL default '2147483647',
  newest_token_age integer NOT NULL default '0',
  PRIMARY KEY  (id)
) WITHOUT OIDS;

CREATE UNIQUE INDEX bayes_vars_idx1 ON bayes_vars (username);

CREATE OR REPLACE FUNCTION greatest_int (integer, integer)
 RETURNS INTEGER
 IMMUTABLE STRICT
 AS 'SELECT CASE WHEN $1 < $2 THEN $2 ELSE $1 END;'
 LANGUAGE SQL;

CREATE OR REPLACE FUNCTION least_int (integer, integer)
 RETURNS INTEGER
 IMMUTABLE STRICT
 AS 'SELECT CASE WHEN $1 < $2 THEN $1 ELSE $2 END;'
 LANGUAGE SQL;

CREATE OR REPLACE FUNCTION put_tokens(inuserid INTEGER,
                                      intokenary BYTEA[],
                                      inspam_count INTEGER,
                                      inham_count INTEGER,
                                      inatime INTEGER)
RETURNS VOID AS ' 
DECLARE
  _token BYTEA;
  new_tokens INTEGER := 0;
BEGIN
  for i in array_lower(intokenary, 1) .. array_upper(intokenary, 1)
  LOOP
    _token := intokenary[i];
    UPDATE bayes_token
       SET spam_count = greatest_int(spam_count + inspam_count, 0),
           ham_count = greatest_int(ham_count + inham_count, 0),
           atime = greatest_int(atime, inatime)
     WHERE id = inuserid 
       AND token = _token;
    IF NOT FOUND THEN 
      -- we do not insert negative counts, just return true
      IF NOT (inspam_count < 0 OR inham_count < 0) THEN
        INSERT INTO bayes_token (id, token, spam_count, ham_count, atime) 
        VALUES (inuserid, _token, inspam_count, inham_count, inatime); 
        IF FOUND THEN
          new_tokens := new_tokens + 1;
        END IF;
      END IF;
    END IF;
  END LOOP;

  IF new_tokens > 0 AND inatime > 0 THEN
    UPDATE bayes_vars
       SET token_count = token_count + new_tokens,
           newest_token_age = greatest_int(newest_token_age, inatime),
           oldest_token_age = least_int(oldest_token_age, inatime)
     WHERE id = inuserid;
  ELSEIF new_tokens > 0 AND NOT inatime > 0 THEN
    UPDATE bayes_vars
       SET token_count = token_count + new_tokens
     WHERE id = inuserid;
  ELSEIF NOT new_tokens > 0 AND inatime > 0 THEN
    UPDATE bayes_vars
       SET newest_token_age = greatest_int(newest_token_age, inatime),
           oldest_token_age = least_int(oldest_token_age, inatime)
     WHERE id = inuserid;
  END IF;
  RETURN;
END; 
' LANGUAGE 'plpgsql'; 

GRANT SELECT, UPDATE, DELETE, INSERT ON TABLE bayes_token TO amavis;
GRANT SELECT, UPDATE, DELETE, INSERT ON TABLE bayes_vars TO amavis;
GRANT SELECT, DELETE, INSERT ON TABLE bayes_seen TO amavis;
GRANT SELECT, DELETE, INSERT ON TABLE bayes_expire TO amavis;
GRANT SELECT ON TABLE bayes_global_vars TO amavis;
GRANT UPDATE, SELECT, INSERT ON bayes_vars_id_seq TO amavis;

