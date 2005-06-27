- Antes de instalar este modulo debe instalar:
     + componentes eBox 
        libebox
	ebox
	network
	objects
     + paquetes Debian
        iptables
     + kernel linux con Netfilter

- Una vez que todas las dependencias se han cumplido, escriba:
	
	./configure
	make install

  configure detectara automaticamente el path de instacion de eBox

- Actualice su fichro /etc/sudoers con el comando ebox-sudoers
