DEPENDENCIAS
------------

+ Componentes eBox  

	+ ebox
	+ ebox-usersandgroups
	+ ebox-network
	+ ebox-firewall
	
+ Paquetes Debian (apt-get install <package>)

	+ samba
	+ libnss-ldap
	+ libcrypt-smbhash-perl
	+ quota
	+ smbldap-tools 
	+ bzip2

+ Otros

	+ un núcleo Linux con soporte para cuotas

INSTALACIÓN
-----------

+ Una vez las dependencias han sido satisfechas, escribir:
	
  ./configure
  make install
  
  + configure detectará la ruta de eBox

+ Copiar samba.schema and ebox.schema del directorio 'schemas' a
  /etc/ldap/schema .

+ Matar al demonio de gconf

  pkill gconf

+ Crear un directorio "spool" para samba con los permisos correctos

  mkdir /var/spool/samba
  chmod 1777 /var/spool/samba

+ Crear algunos subdirectorios:

  mkdir -p /home/samba/users
  mkdir /home/samba/groups
  mkdir /home/samba/profiles
  mkdir /home/samba/logon

+ Cambiar tu fichero /etc/nsswitch.conf para añadir soporte a LDAP:

		passwd:         files ldap
		group:          files ldap
		shadow:         files ldap

+ Ejecutar 

  $prefix/ebox-usersandgroups/ebox-init-ldap genconfig

+ Reiniciar slapd

  /etc/init.d/slapd restart

+ Ahora debes actualizar la base de datos actual de LDAP con los
  objetos usuarios samba:

  ebox-samba-ldap update-users

+ Ejecutar ebox-runit

  ebox-runit

+ Generar smb.conf file y libnss-ldap.conf. 

  $prefix/ebox-samba/ebox-samba-ldap genconfig

+ Poner la contraseña de administrador de samba con tu contraseña de
  administrador de LDAP:

  smbpasswd -w YOUR_LDAP_ADMIN_PASSWORD
		
+ Actualizar las bases de datos actuales de LDAP con los objetos PDC
  samba:

  $prefix/ebox-samba/ebox-samba-ldap update-pdc
	
+ Soporte para cuotas:

  + Tu núcleo Linux debe estar compilado con soporte para cuotas

  + Modificar tu /etc/fstab para dar soporte a coutas (usrquota,
grpquota) en tu punto de montaje para los directorios home:
		
	/dev/hda12      /home           ext3    defaults,usrquota,grpquota      
	
  + Volver a montar la partición o reiniciar 
		
  + Ejecutar:

    quotaon -u "mounting point for home directories"

  + Reiniciar el demonio quota
 
    invoke-rc.d quota restart

+ Reiniciar todos los demonios:

  invoke-rc.d ebox samba restart 
