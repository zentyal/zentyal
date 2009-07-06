#!/bin/sh
PASS="foobar"

# Stop ldap
/etc/init.d/slapd stop
sleep 5;

# Change config admin pass
echo "olcRootPW: $PASS" >> /etc/ldap/slapd.d/cn=config/olcDatabase={0}config.ldif

rm /var/lib/ldap/*

cat <<EOF | slapadd
dn: dc=localdomain
objectClass: top
objectClass: dcObject
objectClass: organization
o: localdomain
dc: localdomain
structuralObjectClass: organization

dn: cn=admin,dc=localdomain
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: admin
description: LDAP administrator
userPassword: foobar
structuralObjectClass: organizationalRole

EOF

sleep 5;
chown -R openldap.openldap /var/lib/ldap

# Start ldap

/etc/init.d/slapd start

/etc/init.d/slapd start

chown -R openldap.openldap /var/lib/ldap

/etc/init.d/slapd stop

chown -R openldap.openldap /var/lib/ldap

/etc/init.d/slapd start

