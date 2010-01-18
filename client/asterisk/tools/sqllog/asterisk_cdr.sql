CREATE TABLE asterisk_cdr ( 
  timestamp timestamp with time zone NOT NULL default now(), 
  clid varchar(80) NOT NULL default '',  
  src varchar(80) NOT NULL default '',  
  dst varchar(80) NOT NULL default '',  
  dcontext varchar(80) NOT NULL default '',  
  channel varchar(80) NOT NULL default '',  
  dstchannel varchar(80) NOT NULL default '',  
  lastapp varchar(80) NOT NULL default '',  
  lastdata varchar(80) NOT NULL default '',  
  duration bigint NOT NULL default '0',  
  billsec bigint NOT NULL default '0',  
  disposition varchar(45) NOT NULL default '',  
  amaflags varchar(20) NOT NULL default '',  
  accountcode varchar(20) NOT NULL default '',  
  uniqueid varchar(32) NOT NULL default '',  
  userfield varchar(255) NOT NULL default ''  
);
CREATE INDEX timestamp_i on access(timestamp);
