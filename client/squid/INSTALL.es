- Antes de instalar este modulo es necesario instalar ebox, libebox,
  ebox-objects, ebox-firewall, ebox-logs squid y dansguardian.

- Una vez ebox está instalado, ejecuta:
	
	./configure
	make install

  el script configure autodetecta la instalación de ebox.

- No ejecute ni squid ni dansguardian en el arranque, este módulo toma el 
  control de ellos.

- Ejecute estas dos líneas para asegurarse que no se ejecutan los
  demonios al arranque:

mv /etc/rc2.d/SXXsquid /etc/rc2.d/K20squid
mv /etc/rc2.d/SXXdansguardian /etc/rc2.d/K20dansguardian

- Pare squid o dansguardian si están ejecutándose.

- Cree una tabla de registro escribiendo:

/usr/lib/ebox-logs/ebox-sql-table add access /usr/share/ebox/sqllog/squid.sql

- Reinicie el demonio de log
	
invoke-rc.d ebox logs restart || true

- Instale los servicios de squid y dansguardian

ebox-runit

- Recarge gconf

pkill gconf
