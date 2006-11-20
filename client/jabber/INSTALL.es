DEPENDENCIAS
------------

+ Componentes eBox

	+ ebox
	+ ebox-network
	+ ebox-firewall
	+ ebox-usersandgroups

+ Paquetes Debian (apt-get install <paquete>)

	+ jabber-common
	+ jabberd2-ldap-bdb

INSTALACIÓN
-----------

- Una vez las dependencias se hayan instalado, escribir:

	./configure
	make install

  configure detectará la ruta base de eBox

- Copia schema/jabber.schema a /etc/ldap/schemas/

- Añade esta línea a /etc/ldap/slapd.conf y reinicia el servicio
  slapd:

	include  /etc/ldap/schema/jabber.schema

- Ejecuta /usr/lib/ebox-jabber/ebox-jabber-ldap para actualizar a los
  usuarios eBox.

- No ejecutes jabberd2-ldap-dbd en el inicio, este módulo tomará su
  control usando runit:

mv /etc/rc2.d/SXXjabberd2-ldap-bdb /etc/rc2.d/KXXjabberd2-ldap-bdb
ebox-runit

- Para jabberd2-ldap-bdb si está ejecutándose