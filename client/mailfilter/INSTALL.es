DEPENDENCIAS
------------

+ Componentes eBox

	+ ebox
	+ ebox-mail

+ Paquetes Debian  (apt-get install <package>)

	+ spamassassin
	+ clamav
	+ clamav-freshclam
	+ amavisd-new

INSTALLACIÓN
------------

- Una vez que todas las dependencias se hayan instalado, escribir:
	
	./configure
	make install

  configure detectará la ruta base de eBox

- Añade el usuario ebox a los grupos amavis y clamav (como superusuario):

  addgroup ebox amavis
  addgroup ebox clamav

- Copiar el esquema schema/mailfilter.schema a /etc/ldap/schema (como
  superusuario).

- Regenerar la configuración de LDAP (como superusuario):

$prefix/lib/ebox-usersandgroups/ebox-init-ldap genconfig
