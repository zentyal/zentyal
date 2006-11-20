DEPENDENCIAS
------------

+ Componentes eBox 
	
	+ ebox
	+ ebox-network
	+ ebox-firewall
	+ ebox-logs

+ Paquetes Debian (apt-get install <paquete>)

	+ dhcp3-server

INSTALACIÓN
-----------

- Una vez que las dependencias se han cumplido, escriba:
	
	./configure
	make install

  configure detectará automáticamente la ruta de instalación de eBox

- No ejecute dhcp3-server al arrancar, este módulo toma el control de él
usando runit:

mv /etc/rc2.d/SXXdhcp3-server /etc/rc2.d/K20dhcp3-server
ebox-runit

- Pare dhcp3-server si está ejecutándose
