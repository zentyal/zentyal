- Antes de instalar este modulo debes instalar:
     + componentes eBox
        libebox
        ebox
     + paquetes Debian
	dhcp3-client
        iproute
        vlan
	net-tools
	dnsutils
     + kernel linux con soport VLAN (801.q)

- Una vez que todas las dependencias se han cumplido, escriba:
	
	./configure
	make install

  configure detectara automaticamente el path donde instalar eBox

- Actualice su /etc/sudoers con el comando ebox-sudoers.

- Puede importar su configuracion actual de red en eBox ejecutando
ebox-netcfg-import
