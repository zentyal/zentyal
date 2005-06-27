- Para instalar este módulo es necesario instalar eBox base, openswan y un
  kernel linux con soporte para IPSec.

- Cuando se todas las dependencias estén satisfechas, basta con ejecutar:
	
	./configure
	make install

  configure autodetectará la ruta de eBox base para instalar el módulo

- Actualiza el fichero sudoers con el comando ebox-sudoers.

- openswan no debería ejecutarse automáticamente en el arranque, este módulo lo
  arrancará cuando se necesite:

  mv /etc/rcX.d/SXXipsec /etc/rcX.d/KXXipsec

  (reemplazar las X's con los números apropiados)
