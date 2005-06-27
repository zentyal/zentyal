CREATE SCHEMA squid;

CREATE TABLE squid.access (
	date timestamp,
	host inet,
	txt_code varchar(20),
	code integer,
	size integer,
	method varchar(5),
	url varchar(80),
	type varchar(20)
);
