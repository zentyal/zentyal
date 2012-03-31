CREATE TABLE bayes_expire (
  id int(11) NOT NULL default '0',
  runtime int(11) NOT NULL default '0',
  KEY bayes_expire_idx1 (id)
) ENGINE = MyISAM;

CREATE TABLE bayes_global_vars (
  variable varchar(30) NOT NULL default '',
  value varchar(200) NOT NULL default '',
  PRIMARY KEY  (variable)
) ENGINE = MyISAM;

INSERT INTO bayes_global_vars VALUES ('VERSION','3');

CREATE TABLE bayes_seen (
  id int(11) NOT NULL default '0',
  msgid varchar(200) binary NOT NULL default '',
  flag char(1) NOT NULL default '',
  PRIMARY KEY  (id,msgid)
) ENGINE = MyISAM;

CREATE TABLE bayes_token (
  id int(11) NOT NULL default '0',
  token char(5) NOT NULL default '',
  spam_count int(11) NOT NULL default '0',
  ham_count int(11) NOT NULL default '0',
  atime int(11) NOT NULL default '0',
  PRIMARY KEY  (id, token),
  INDEX bayes_token_idx1 (id, atime)
) ENGINE = MyISAM;

CREATE TABLE bayes_vars (
  id int(11) NOT NULL AUTO_INCREMENT,
  username varchar(200) NOT NULL default '',
  spam_count int(11) NOT NULL default '0',
  ham_count int(11) NOT NULL default '0',
  token_count int(11) NOT NULL default '0',
  last_expire int(11) NOT NULL default '0',
  last_atime_delta int(11) NOT NULL default '0',
  last_expire_reduce int(11) NOT NULL default '0',
  oldest_token_age int(11) NOT NULL default '2147483647',
  newest_token_age int(11) NOT NULL default '0',
  PRIMARY KEY  (id),
  UNIQUE bayes_vars_idx1 (username)
) ENGINE = MyISAM;

GRANT SELECT, UPDATE, DELETE, INSERT ON TABLE bayes_token TO amavis;
GRANT SELECT, UPDATE, DELETE, INSERT ON TABLE bayes_vars TO amavis;
GRANT SELECT, DELETE, INSERT ON TABLE bayes_seen TO amavis;
GRANT SELECT, DELETE, INSERT ON TABLE bayes_expire TO amavis;
GRANT SELECT ON TABLE bayes_global_vars TO amavis;
