DEPENDENCIAS
------------

+ Componentes eBox

	+ ebox

+ Paquetes Debian (apt-get install <paquete>)

	+ openswan

+ Otros

	+ Un núcleo Linux con IPSec habilitado

INSTALACIÓN
-----------

- Cuando todas las dependencias estén satisfechas, basta con ejecutar:
	
	./configure
	make install

  configure autodetectará la ruta de eBox base para instalar el módulo

- openswan no debería ejecutarse automáticamente en el arranque, este módulo lo
  arrancará cuando se necesite:

  mv /etc/rcX.d/SXXipsec /etc/rcX.d/KXXipsec

  (reemplazar las X's con los números apropiados)
