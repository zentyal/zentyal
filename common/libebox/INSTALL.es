DEPENDENCIAS
------------

+ Paquetes Debian:

# apt-get install <paquete>

	+ perl
	+ perl-modules
	+ sudo
	+ liblog-dispatch-perl
	+ liblog-log4perl-perl
	+ liblocale-gettext-perl
	+ libnet-ip-perl
	+ liberror-perl
	+ libdevel-stacktrace-perl
	+ libhtml-mason-perl
	+ gettext

+ modulos del cpan

	ninguno actualmente

INSTALATION
-----------

1.- Configurar:

    $ ./configure <parametros>

    Acepta los parametros estandar de GNU para configure, ejecute
    ./configure --help para obtener una lista

    Parametro sugerido: --localstatedir=/var/ , para instalar los
    datos variables en /var/lib, en lugar del lugar por defecto
    $prefix/var/lib/

2.- Instalacion, como root:

    $ make install
