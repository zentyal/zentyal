DEPENDENCIAS
------------

+ Componentes de eBox

	+ libebox

+ Paquetes Debian (apt-get install <package>)

	+ apache-perl
	+ libapache-mod-perl
	+ libapache-mod-ssl
	+ libapache-authcookie-perl
	+ libgnome2-gconf-perl
	+ libsys-cpu-perl
	+ libsys-cpuload-perl
	+ libproc-process-perl
	+ libapache-singleton-perl
	+ runit

+ Módulos de CPAN 

	+ Readonly

RECOMENDADO
-----------

+ Paquetes Debian (apt-get install <package>)
	+ eject
        + cdrdao
	+ mkisofs
	+ cdrecord
	+ dvd+rw-tools

+ Módulos de CPAN

	+ Readonly::XS


INSTALACIÓN
-----------

1.- Configuración:

    $ ./configure <arguments>

    Acepta los argumentos estándar de los configure de GNU. Ejecutar
    ./configure --help para obtener una lista.

    Apache y libebox se autodetectan.

2.- Instalación, como superusuario:

    $ make install

3.- Crear un usuario ebox y un grupo ebox, el directorio home para el usuario
    debe ser $prefix/var/lib/ebox, si se ha usado --localstatedir=/var en la
    configuracion de libebox:
    	addgroup --system ebox
	adduser --system --home /var/lib/ebox --no-create-home \
		--disabled-password --ingroup ebox ebox

4.- Crear los directorios log y tmp en $prefix/var/lib/ebox o /var/lib/ebox
    si se utilizó --localstatedir=/var y cambiar el propietario del directorio
    completo al usuario ebox:

    mkdir -p /var/lib/ebox/tmp
    mkdir -p /var/lib/ebox/log
    chown -R ebox.ebox /var/lib/ebox

5.- Permitir al usuario de apache ejecutar comandos como superusuario
    utilizando sudo.
    Para ello redirigir la salida del comando ebox-sudoers al fichero 
    /etc/sudoers.

    ebox-sudoers > /etc/sudoers

6.- Copiar conf/.gconf.path al directorio home del usuario ebox
    ( /var/lib/ebox/ si se han seguido las instrucciones anteriores ) y:

	mkdir /var/lib/ebox/gconf
	chown ebox.ebox /var/lib/ebox/gconf

7.- Eliminar el enlace a /etc/init.d/apache-perl de /rc2.d/, el script ebox
    se encargará de arrancar y parar el apache a través de runit. Para
    instalar los scripts de runit:

    ebox-runit
 
8.- Para que ebox se inicie en el arranque de la máquina:

    cp tools/ebox /etc/init.d

    Añade una línea como esta:
EB:2:once:/etc/init.d/ebox start
    al final (después de las líneas de runit) del fichero /etc/inittab

9.- Crear ebox.pem mezclando ssl.cert y ssl.key:

    mkdir /etc/ebox/ssl.pem
    cat /etc/ebox/ssl.crt/ebox.cert \
        /etc/ebox/ssl.key/ebox.key > /etc/ebox/ssl.pem/ebox.pem


10.- Arrancar ebox:
	
	/etc/init.d/ebox start

EJECUCIÓN
---------

La url de la interfaz de administración es:

https://<ip address>/

La clave por defecto es 'ebox'. Se puede cambiar en la sección general de
configuración.

Los registros de ebox y de apache se encuentran en $localstatedir/ebox/log
