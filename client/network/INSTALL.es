DEPENDENCIAS
------------

+ Componentes eBox

	+ ebox

+ Paquetes Debian (apt-get install <paquete>)

	+ dhcp3-client
	+ iproute
        + vlan
	+ net-tools

+ Otros

	+ un núcleo Linux con VLAN (801.q) habilitado


INSTALACIÓN
-----------

- Una vez que todas las dependencias se han cumplido, escriba:
	
	./configure
	make install

  configure detectara automaticamente el path donde instalar eBox

- Puede importar su configuracion actual de red en eBox:

 $prefix/ebox-network/ebox-netcfg-import
