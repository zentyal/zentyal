#!/bin/sh
ADMIN_PASS="master-foobar"
EBOX_PASS="ebox-foobar"

# Stop ldap
/etc/init.d/slapd stop
sleep 5;

# Change config admin pass
echo "olcRootPW: $ADMIN_PASS" >> /etc/ldap/slapd.d/cn=config/olcDatabase={0}config.ldif

# Change eBox LDAP pass
echo -n "$EBOX_PASS" > /var/lib/ebox/conf/ebox-ldap.passwd

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
userPassword: $ADMIN_PASS
structuralObjectClass: organizationalRole

EOF

sleep 5;
chown -R openldap:openldap /var/lib/ldap

# Start ldap

/etc/init.d/slapd start
