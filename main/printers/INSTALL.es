DEPENDENCIAS
------------

+ Componentes eBox 

	+ ebox
	+ ebox-network
	+ ebox-firewall
	+ ebox-usersandgroups
	+ ebox-samba

+ Paquetes Debian  (apt-get install <package>)

	+ cupsys
	+ libnet-cups-perl
	+ foomatic-db
	+ foomatic-db-engine
	+ foomatic-filters
	+ foomatic-filters-ppds

INSTALACIÓN
-----------

- Una vez todas las dependencias han sido satisfechas, ejecutar:
	
	./configure
	make install

  configure detectará la ruta de eBox

- Añadir ebox al grupo lpadmin

- No ejecutar cupsys al inicio, este módulo tomará el control de ello
  con runit:

mv /etc/rc2.d/SXXcupssys /etc/rc2.d/K20cupsys
ebox-runit

- Parar cupsys si está ejecutándose
