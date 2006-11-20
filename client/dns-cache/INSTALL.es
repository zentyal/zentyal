DEPENDENCIAS
------------

+ Componentes eBox
	
	+ ebox
	+ ebox-network
	+ ebox-firewall

+ Paquetes Debian (apt-get install <package>)

	+ bind9

INSTALLACIÓN
------------

- Una vez que las dependencias se han cumplido, escriba:
	
	./configure
	make install

  configure detectara automaticamente el path de instalacion de eBox

- No ejecute bind9 al arrancar, este modulo toma su control:

mv /etc/rc2.d/SXXbind9 /etc/rc2.d/KXXbind9

- Pare bind9 si esta en ejecucion
