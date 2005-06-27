- Antes de instalar este modulo debe instalar:
     + componentes eBox 
        libebox
        ebox
        network
        firewall
     + paquetes Debian
        bind9

- Una vez que las dependencias se han cumplido, escriba:
	
	./configure
	make install

  configure detectara automaticamente el path de instalacion de eBox

- Actualice su fichero /etc/sudoers con el comando ebox-sudoers

- No ejecute bind9 al arrancar, este modulo toma su control:

mv /etc/rc2.d/SXXbind9 /etc/rc2.d/KXXbind9

- Pare bind9 si esta en ejecucion
