DEPENDENCIAS
------------

+ Paquetes debian

# apt-get install <package>

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

+ modulos de cpan

	ninguno en este momento

+ componentes de eBox:
	libebox

INSTALACION
-----------

1.- Configuracion:

    $ ./configure <arguments>

    Acepta los argumentos estandar de los configure de GNU. Ejecutar
    ./configure --help para obtener una lista.

    Apache y libebox se autodetectan.

2.- Instalacion, como root:

    $ make install

3.- Crear un usuario ebox y un grupo ebox, el directorio home para el usuario
    debe ser $prefix/var/lib/ebox, si se ha usado --localstatedir=/var en la
    configuracion de libebox:
    	addgroup --system ebox
	adduser --system --home /var/lib/ebox --no-create-home \
		--disabled-password --ingroup ebox ebox

4.- Crear los directorios log y tmp en $prefix/var/lib/ebox o /var/lib/ebox
    si se utilizo --localstatedir=/var y cambiar el propietario del directorio
    completo al usuario ebox:

    mkdir -p /var/lib/ebox/tmp
    mkdir -p /var/lib/ebox/log
    chown -R ebox.ebox /var/lib/ebox

5.- Permitir al usuario de apache ejecutar comandos como root utilizando sudo.
    Para ello redirigir la salida del comando ebox-sudoers al fichero 
    /etc/sudoers.

    ebox-sudoers > /etc/sudoers

6.- Copiar conf/.gconf.path al directorio home del usuario ebox
    ( /var/lib/ebox/ si se han seguido las instrucciones anteriores ) y:

	mkdir /var/lib/ebox/gconf
	chown ebox.ebox /var/lib/ebox/gconf

7.- Eliminar el link a /etc/init.d/apache-perl de /rc2.d/, el script ebox
    se encargara de arrancar y parar el apache a través de runit. Para
    insalar los scripts de runit:

    ebox-runit
 
8.- Para que ebox se inicie en el arranque de la maquina:

    cp tools/ebox /etc/init.d

    Añade una línea como esta:
EB:2:once:/etc/init.d/ebox start
    al final (después de las líneas de runit) del fichero /etc/inittab

9.- Arrancar ebox:
	
	/etc/init.d/ebox start

EJECUCION
---------

La url del interface de administracion es:

https://<ip address>/

La clave por defecto es 'ebox'. Se puede cambiar en la seccion general de
configuracion.

Los logs de ebox y de apache se encuentran en $localstatedir/ebox/log
