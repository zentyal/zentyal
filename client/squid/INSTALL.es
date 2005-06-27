- Antes de instalar este modulo es necesario instalar ebox-base, 
  squid y dansguardian.

- Una vez ebox está instalado:
	
	./configure
	make install

  el script configure autodetecta la instalación de ebox.

- Actualice el fichero de configuracion de sudo con el comando ebox-sudoers

- No ejecute ni squid ni dansguardian en el arranque, este modulo toma el 
  control de ellos:

mv /etc/rc2.d/SXXsquid /etc/rc2.d/K20squid
mv /etc/rc2.d/SXXdansguardian /etc/rc2.d/K20dansguardian

- Pare squid o dansguardian si estan corriendo.
