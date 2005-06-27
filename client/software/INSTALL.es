- Para instalar este modulo es necesario tener instalado previamente eBox base y
  libapt-pkg-perl

- Una vez se tenga eBox base instalado:
	
	./configure
	make install

  configure autodetectará la ruta donde está instalado eBox base.

- Actualiza el fichero sudoers con el comando ebox-sudoers.

- Debconf y ucf deberían estar configurados para no hacer preguntas de forma
  interactiva al instalar/actualizar un paquete.
