- Antes de instalar este modulo debe instalar:
     + componentes eBox
        libebox
        ebox
        network
        firewall
     + paquetes Debian
        dhcp3-server

- Una vez que las dependencias se han cumplido, escriba:
	
	./configure
	make install

  configure detectara automaticamente el path de instalacion de eBox

- Actualice el fichero /etc/sudoers con ebox-sudoers

- No ejecute dhcp3-server al arrancar, este modulo toma el control de el
usando runit:

mv /etc/rc2.d/SXXdhcp3-server /etc/rc2.d/K20dhcp3-server
ebox-runit

- Pare dhcp3-server si esta ejecutandose
