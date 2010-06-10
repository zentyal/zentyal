Herramientas de soporte
************************

.. sectionauthor:: Enrique J. Hernández <ejhernandez@ebox-platform.com>

A la hora de obtener soporte para tu eBox [#]_ hay algunas utilidades para facilitar el proceso.


.. [#] http://www.ebox-technologies.com/services/support/



Informe de la configuración
--------------------------------------

El informe de la configuración es un archivo que contiene la configuración de
eBox y bastante información sobre el sistema. Proveerlo cuando se solicite
soporte puede ahorrar tiempo ya que probablemente contendrá la información
requerida por le ingeniero de soporte.

Se puede generar el informe de dos maneras::
 1) En la interfaz web, acceder a  :menuselection:`Sistema -> Informe de
   configuración`; pulsa el el botón para que se empiece a generar el informe,
   una vez listo tu navegador lo descargara.
 2) En la linea de comandos, ejecuta el comando
   `/usr/share/ebox/ebox-configuration-report`. Cuando el informe este listo, el
   comando indicara su localización en el sistema de archivos/



Acceso remoto de soporte
-------------------------

En casos difíciles, si tu entorno de trabajo lo permite, puede ser útil dejar
acceder al ingeniero de soporte a tu servidor eBox.

El paquete **ebox-remoteservices** contiene una característica para facilitar este
proceso. El acceso remoto se hace usando ssh y cifrado de clave publica; de esta
manera no hace falta compartir ninguna contraseña  [#]_. 

Además el acceso solo estará disponible a través de la Red Virtual Privada del
Centro de Control; esta restricción esta pensad para incrementar la seguridad
del proceso de soporte. Para las situaciones en las que la eBox no se ha podido
subscribir al Centro de Control o cuando la Red Privada Virtual no funciona
correctamente, existe una opción para permitir el acceso desde cualquier
dirección de Internet.


El acceso solo estará
disponible en tanto que esta opción este activada, por ello solo es recomendable
activarla durante el tiempo en que se necesite.

Antes de activarla, se deben cumplir estos requisitos:

 * Tu servidor debe o bien estar subscrito al Contro Center o ser visible en Internet.
 * El servidor sshd debe estar corriendo.
 * En caso de usar cortafuegos debe estar configurado para permitir conexiones
   ssh entrantes.
 * En la configuración de sshd la opción `PubkeyAuthentication` _no_ debe estar
   desactivada. 

Para activar esta característica, entra en :menuselection:`General->Acceso
remoto de soporte` y activar el control :guilabel:`Permitir acceso remoto a
personal de eBox`, a continuación guarda los cambios de la manera usual.  

Si quieres permitir acceso desde Internet, deberás activar
también la opción :guilabel:`Permitir acceso desde cualquier dirección de
Internet`. En este caso deberás suministrar tu dirección de Internet al
ingeniero de soporte y asegurarte que el acceso ssh esta permitido desde la Internet.

Después de dar la dirección de Internet del servidor al ingeniero de soporte,
este podrá entrar en tu servidor mientras esta opción este activada.

Puedes usar el programa `screen` para ver en tiempo real la sesión de soporte,
esto puede ser útil para compartir información.

Para hacer esto debes tener una sesión con un usuario que pertenezca al grupo
`adm`. El usuario creado durante el proceso de instalación cumple este
requisito. Puedes unirte a la sesión de soporte con este comando::


screen -x ebox-remote-support/

Por defecto tan solo puedes ver la sesión; si necesitas escribir en la linea de
comandos y ejecutar programas deberás pedir al ingeniero de soporte que le otorgue
los permisos adecuados a tu usuario.


.. [#] Puedes encontrar mas informacion sobre criptografia de llave publica en
       el capitulo de  :ref:`vpn-ref`.
