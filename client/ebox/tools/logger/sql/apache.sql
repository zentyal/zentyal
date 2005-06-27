CREATE SCHEMA apache;

CREATE TABLE apache.access (
	host inet,
	www_user varchar(20),
	date timestamp,
	method varchar(5),
	url varchar(80),
	protocol varchar(10),
	code integer,
	size integer,
	referer varchar(80),
	ua varchar(120)
);
