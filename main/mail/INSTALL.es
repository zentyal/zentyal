DEPENDENCIAS
------------

+ Componentes eBox

	+ ebox
	+ ebox-network
	+ ebox-firewall
	+ ebox-objects
	+ ebox-usersandgroups

+ Paquetes Debian testing (apt-get install <package>)

	+ Postfix con el patch VDA aplicado
	+ postfix-tls
	+ postfix-ldap
	+ courier-pop
	+ courier-imap
	+ courier-pop-ssl
	+ courier-imap-ssl
	+ courier-authdaemon
	+ courier-ldap
	+ libsasl2-modules
	+ libsasl2
	+ sasl2-bin

INSTALACIÓN
-----------

- Una vez todos las dependencias se hayan instalado, escribir:
	
	./configure
	make install

  configure detectará la ruta base de eBox 

- Copiar conf/*.pem a /etc/postfix/sasl/, creando el directorio si es
  necesario

- Ejecutar como superusuario (debe estar en $prefix/lib/ebox-mail/ ):
	./ebox-mail-ldap

- No se deben lanzar los servicios al comienzo, este módulo toma el
  control de todos ellos usando runit:

mv /etc/rc2.d/SXXpostfix /etc/rc2.d/KXXpostfix
mv /etc/rc2.d/SXXcourier-authdaemon /etc/rc2.d/KXXcourier-authdaemon
mv /etc/rc2.d/SXXcourier-imap /etc/rc2.d/KXXcourier-imap
mv /etc/rc2.d/SXXcourier-imap-ssl /etc/rc2.d/KXXcourier-imap-ssl
mv /etc/rc2.d/SXXcourier-pop-ssl /etc/rc2.d/KXXcourier-pop-ssl
mv /etc/rc2.d/SXXcourier-pop /etc/rc2.d/KXXcourier-pop

- Parar todos estos servicios si se están ejecutando.
