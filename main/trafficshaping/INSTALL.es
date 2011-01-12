DEPENDENCIAS
------------

+ Componentes eBox 

	+ ebox
	+ ebox-network
	+ ebox-firewall

+ Paquetes Debian  (apt-get install <package>)

	+ libtree-perl
	+ iptables
	+ iproute
+ Otros 

	+ un núcleo Linux con Netfilter habilitado
	+ un núcleo Linux con QoS habilitado

INSTALACIÓN
-----------

- Una vez se han cumplido las dependencias, escribir:
	
	./configure
	make install

  configure autodetectará la ruta base de eBox para instalar

- Recarga el demonio de apache

        pkill apache
