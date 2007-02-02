DEPENDENCIAS
------------

+ Componentes eBox
	
	+ ebox

+ Paquetes Debian (apt-get install <package>)

	+ openssl (>= 0.9.7e)
	+ libdate-calc-perl
	+ libfile-slurp-perl
        + libfile-copy-recursive-perl

+ Módulos del CPAN 

	+ Perl6::Junction

INSTALACIÓN
-----------

- Una vez eBox está instalado, ejecuta:
	
	./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc
	make install

  el script configure autodetecta la instalación de eBox.

- Recargar gconf

	pkill gconf

- Todos los nuevos certificados se almacenarán en /var/lib/ebox/CA
