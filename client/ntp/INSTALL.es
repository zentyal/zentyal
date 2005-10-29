- Antes de instalar este modulo es necesario instalar ebox-base y ntp-server

- Una vez ebox está instalado:
	
	./configure
	make install

  el script configure autodetecta la instalación de ebox y de ntp-server.

- Actualice el fichero de configuracion de sudo con el comando ebox-sudoers

- Ejecute el script tools/ebox-timezone-import como root.

- No ejecute ntp-server en el arranque, este modulo toma el control de
  ntp-server usando runit:

mv /etc/rc2.d/SXXntp-server /etc/rc2.d/KXXntp-server
ebox-runit

- Pare ntp-server si está corriendo.
