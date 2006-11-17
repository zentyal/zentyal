DEPENDENCIAS
------------

+ Componentes eBox 
	
	+ ebox

+ Paquetes debian (apt-get install <paquete>)

	+ slapd
	+ libnet-ldap-perl

INSTALACIÓN
-----------

- Una vez ebox haya sido instalado
	
	./configure --sysconfdir=/etc --localstatedir=/var --prefix=/usr
	make install

  configure detectará la ruta base de eBox para instalarse

- Ver debian/ebox-usersandgroups.postinst del paquete debian
  ebox-usersandgroups para detalles sobre la configuración de LDAP