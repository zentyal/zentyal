* Para instalar este módulo eBox necesitas instalar:
	+ componentes eBox
	  ebox
	+ Paquetes debian
	  postgresql
	  libdb-pg-perl
	  libfile-tail-perl

* Una vez que las dependencias se han instalado, ejecutar:
	
	./configure --sysconfdir=/etc --localstatedir=/var --prefix=/usr
	make install

  configure detectará la ruta de ebox para instalarse

* Matar el demonio gconf

  pkill gconf

* Poner los permisos 0666 para /etc/ebox/90eboxpglogger.conf

* Copiar pgpass de conf/pgpass a .pgpass en /var/lib/ebox con permisos
  0600 y propietario ebox.ebox

* Deberías crear la base de datos en el gestor postgresql

  * Ejecuta los siguientes comandos 

	# Entre como usuario postgres en el SGBD
    $ su postgres -c "psql template1"
	# Create an eboxlogs database
    > CREATE DATABASE eboxlogs;
	# Create an eboxlogs user
    > CREATE USER eboxlogs PASSWORD 'eboxlogs';
    > GRANT ALL ON DATABASE eboxlogs TO eboxlogs;
    > \q

 
 * Se debería crear el fichero /etc/postgresql/pg_hba.conf con el
   siguiente contenido:
<FICHERO>
# TYPE  DATABASE    USER        IP-ADDRESS        IP-MASK           METHOD
# Database administrative login by UNIX sockets
local   all         postgres                                        ident sameuser
#
# eBox log database
host    $db_name    $db_user     127.0.0.1       255.255.255.255 md5
local   $db_name    $db_user                                        md5
# All IPv4 connections from localhost
host    all         all         127.0.0.1         255.255.255.255  ident sameuser
# 
# All IPv6 localhost connections
host    all         all         ::1               ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff        ident sameuser
host    all         all         ::ffff:127.0.0.1/128                ident sameuser
# 
# reject all other connection attempts
host    all         all         0.0.0.0           0.0.0.0           reject
<FIN DE FICHERO>

* Para el demonio postgresql si está ejecutándose