- Antes de instalar este modulo es necesario instalar ebox, libebox, ebox-firewall,
  ntpdate y ntp-server

- Una vez ebox está instalado:
	
	./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc
	make install

  el script configure autodetecta la instalación de ebox y de ntp-server.

- Ejecute el script /usr/lib/ebox-ntp/ebox-timezone-import con
  permisos de administrador.

- No ejecute ntp-server en el arranque, este módulo toma el control de
  ntp-server usando runit:

mv /etc/rc2.d/SXXntp-server /etc/rc2.d/KXXntp-server
ebox-runit

- Pare ntp-server si está corriendo.
