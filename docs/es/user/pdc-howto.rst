Usando eBox como Controlador Primario de Dominio
--------------------------------------------------

`eBox Platform <http://www.ebox-platform.com>`_ es un servidor de codigo abierto
para pequeñas y medianas empresas que te permite gestionar tus servicios, tales
como cortafuegos,  DHCP, DNS, VPN, proxy, IDS, e-mail, archivos e impresoras
compartidas, VoIP, IM y muchos maas. Esta funcionalidades están fuertemente
integradas, automatizando tareas, evitando errores y ahorrando tiempo a los
administradores de sistemas.

Este tutorial te mostrara, paso a paso, como usar eBox como un Controlador
Primario de Dominio de Windows. Cuando lo cabemos estará usando eBox Platform
para la gestión de usuarios y recursos compartidos de tu dominio Windows.



1. Instalando el servidor eBox
=======================================

La instalación puede hacerse de dos maneras distintas:

- Usando el instalador de la eBox Platform (recomendado).
- Usando una instalación ya existente de Ubuntu TLS Server.

En el segundo caso, necesitaras añadir los `repositorios
<http://launchpad.net/~ebox/+archive/1.4>`_ de eBox Platform e instalar los
paquetes que te interesen.

De todas maneras, en el primer caso la instalación y despliegue son mas fáciles
ya que todas las dependencias están en un único disco y  además se realizan
preconfiguraciones durante el proceso de instalación. Por esta razón, se usara
este método en el tutorial. 



.. image:: images/pdc-howto/eBox-installer.png
   :scale: 80
   :alt:    Instalador de eBox Platform 

El instalador de eBox Platform esta basado en el instalador de Ubuntu y aquellos
que estén familiarizados con este ultimo encontraran el proceso muy similar. En
este documento no cubrimos la instalación de Ubuntu, pero si tienes dudas puedes
consultar su `documentación oficial de instalación
<https://help.ubuntu.com/8.04/serverguide/C/installation.html>`_.

Una vez la instalación del sistema base halla finalizado, el sistema se
reiniciaría y dará comienzo el proceso de instalación de eBox. Primero, te
preguntara que componentes de software deben ser instalados. Hay dos maneras de
seleccionar los componentes que quieras desplegar en tu sistema, en este caso
elegiremos el método `simple`.



.. image:: images/pdc-howto/package-selection-method.png
   :scale: 80
   :alt:    Selection of the installation method 

Después de escoger el método `simple`, se te mostrara una lista de perfiles de
software. En nuestro caso tan solo seleccionaremos el perfil `Oficina` que
contiene todos los componentes necesarios para el PDC. Esta selección no va a
ser inalterable y maas adelante puedes instalar o eliminar paquetes de software
según dicten tus necesidades.

.. image:: images/pdc-howto/profiles.png
   :scale: 60
   :alt:    Selection of the profiles 

Una vez seleccionados los componentes a instalar, una barra de progreso te
ira mostrando el estado del proceso de instalación.


   
.. image:: images/pdc-howto/installing-eBox.png
   :scale: 80
   :alt:    Installing eBox Platform 

Cuando la instalación termine, se te pedirá introducir una contraseña para
acceder a la interfaz web de eBox Platform.


.. image:: images/pdc-howto/password.png
   :scale: 80   
   :alt:    Enter password to access the web interface 

Necesitaras confirmar la contraseña.


.. image:: images/pdc-howto/repassword.png
   :scale: 80      
   :alt:    Confirm password to access the web interface 

Después el instalador intentara preconfigurar algunos parámetros básicos. 

Primero, te preguntara si alguna de tus interfaces es externa, es decir
conectada a una red que no sea interna, pro ejemplo la tarjeta conectada al
router que da acceso a Internet. Se aplicaran políticas estrictas al trafico
entrante por interfaces externas. Dependiendo del papel que juegue el servidor,
p.e. situado dentro de tu red interna proveyendo únicamente servicios locales,
es posible que no halla ninguna interfaz externa.


.. image:: images/pdc-howto/select-external-iface.png
   :scale: 80   
   :alt:    Selection of the external interface 

A continuación te preguntara por un nombre de dominio virtual de correo. Como no
vamos a usar el servicio de correo en este tutorial, puedes introducir cualquier
nombre que te convenga.

   
.. image:: images/pdc-howto/vmaildomain.png
   :scale: 80   
   :alt:    Set default mail virtual domain name 

Una vez respondidas estas preguntas, los módulos que hallas instalados serán preconfigurados.

   
   
.. image:: images/pdc-howto/preconfiguring-ebox.png
   :scale: 80   
   :alt:    Preconfiguring eBox packages 

Cuando este proceso se complete, un mensaje te informara sobre como conectar a
la interfaz web de eBox Platform.

   
.. image:: images/pdc-howto/ebox-ready-to-use.png
   :scale: 80   
   :alt:    eBox ready to use message 



2. Entrando a la interfaz web
=======================================

Ya estas listo para entrar por primera vez a la interfaz web de eBox.  Apunta tu
navegador hacia `https://dirección/` siendo la dirección aquella que te
suministro el instalador en el paso anterior.

Como el servidor eBox tiene un nuevo certificado autofirmado, tu navegador
probablemente te preguntara si puede considerarlo de confianza. Haz que tu
navegador confié en el para poder continuar.

Después te sera mostrada la pantalla de acceso, para entrar introduce la
contraseña de administración de eBox que estableciste durante el proceso de instalación.


   
.. image:: images/pdc-howto/01-login.png
   :scale: 80   
   :alt:    login screen 


Después de entrar, se te mostrara el sumario de la pagina del servidor.

   
   
.. image:: images/pdc-howto/02-homepage.png
   :scale: 80   
   :alt:    summary page 



3. Activando y desactivando módulos
=======================================

El siguiente paso es desactivar los módulos que no son necesarios para el
servidor PDC. Para hacerlo en el menú de la izquierda selecciona `Estado del
modulo`. En dicha pagina se te mostrara la lista de los módulos de eBox
instalados y una casilla para activarlos o desactivarlos.

   
.. image:: images/pdc-howto/module-status.png
   :scale: 80   
   :alt:    module status page 

Por defecto todos los módulos instalados están activados pero para hacer un uso
mas eficiente de los recursos de tu sistema, puedes desactivar los módulos que
no son necesitados por el PDC.
Los módulos que necesita el PDC son:

-  Red
-  Registros
-  Usuarios y Grupos
-  Compartición de Archivos
-  Antivirus

Puedes desactivar cualquier otro modulo para ahorrar recursos de tu sistema.


5. Creando grupos
=======================================

Puedes necesitar grupos de usuarios en tu dominio. Para crear grupos, en el menú
de la izquierda selecciona `Usuarios y Grupos -> Añadir grupo`. Se te solicitara un nombre
para el grupo y opcionalmente podrás establecer un comentario para el mismo.

   
   
.. image:: images/pdc-howto/add-group.png
   :scale: 80   
   :alt:    add group form 


Si pulsas el botón de `Añadir y Editar` en vez del de `Añadir`, se te llevara a
la pagina de `Editar grupAfter a group creation you will be forwarded to the Edit group
page. We are not interested in any setting here right now, but
remember you can come back to this page selecting in left menú
Groups -> Edit group.

We will create the group *TI* for this tutorial. You can also
create any other necessary groups for your domain.
o`. Ahora no estamos interesados en ninguno de los
parametros de esa pagina, así que pulsaremos el botón de `Añadir`. En todo caso
recuerda que puedes visitar esa pagina seleccionando la casilla `Editar` en la
lista de usuarios.

Para este tutorial crearemos el grupo *TI*. También puedes crear cualquier grupo
que veas necesario para tu dominio.


6. Creando usuarios
=======================================

Para crear tus usuarios de dominio, selecciona en el menú izquierdo `Usuarios y
Grupos -> Añadir usuario`. Se te mostrara un formulario para nadir el nuevo
usuario con los siguientes campos:


-  Nombre de usuario: nombre con el que sera identificado el usuario por el
   sistema.
-  Nombre: nombre del usuario.
-  Apellido: apellido del usuario.
-  Comentario: campo para añadir un comentario al usuario.
-  Contraseña y Confirmar contraseña: contraseña para el usuario, podrá cambiarla
   después de conectar al dominio. Posteriormente veremos como definir políticas
   de contraseñas.
-  Grupo: grupo primario del usuario. Después el usuario puede unirse a mas grupos.

   
   
.. image:: images/pdc-howto/add-user.png
   :scale: 80   
   :alt:    Add user form 

Para este tutorial crearemos un usuario llamado *pdcadmin*. Puedes rellenar los
otros campos con valores que consideres apropiados. Pulsa en `Añadir y editar`
para ser redirigido a la pagina `Editar usuario`, recuerda que puedes volver a
esta pagina en cualquier momento seleccionando en el menú izquierdo `Usuarios y
Grupo -> Usuarios` y pulsando en la casilla de `Editar`.

En la pagina de `Editar usuario` hay parametros de PDC, están bajo la cabecera
`Cuenta de compartición de ficheros o de PDC`.

Puedes activar o desactivar la cuenta, una cuenta desactivada no puede entrar n
ser usada en el dominio. Dejaremos nuestra cuenta de usuario activada.

También es posible otorgar permisos administrativos al usuario. Un usuario con
permisos administrativos puede añadir ordenadores al dominio, por lo que
necesitaras al menos un usuario con estos permisos. Por esta razón, activaremos
los permisos administrativos en el usuario *pdcadmin*.

Hay otro campo que nos permite cambiar la cuota de disco para el usuario. No nos
hace falta modificar ese campo ahora.


  
   
.. image:: images/pdc-howto/pdc-user-settings.png
   :scale: 80   
   :alt:    pdc-related user settings 

Ahora puedes crear mas cuentas de usuarios para tus usuarios normales. Solo
necesitan una cuenta activada sin derechos de administración. Si crees que su
cuota de disco es demasiada pequeña o grande puedes editarla también.


7. Configurando parametros generales de PDC
============================================

Para configurar los parametros generales de PDC y compartimiento de archivos, en
el menú izquierdo selecciona `Compartir ficheros`.

En la pestaña `Parametros generales` marcaremos la casilla `Activar
PDC`. También puedes cambiar el nombre de dominio de su valor pro defecto a uno
que tenga sentido para tu organización o dominio. En el tutorial usaremos *ebox*
como nombre de dominio.

Asimismo puedes cambiar el nombre de Netbios. Este sera el nombre que
identificara al servidor cuando use el protocolo Netbios. Este nombre no debe
ser el mismo que el dominio, sin considerar mayúsculas, o podremos tener
problemas de conexión. Usaremos *ebox-server* como nombre de netbios.

En el campo `Descripción` puedes introducir un texto para identificar mejor el
dominio.

En campo `Limite de cuota` es el valor que se asignara en cuota de disco a los
nuevos usuarios.

El control `Activar perfiles remotos` controla si el perfil de escritorio del
usuario es guardado en el PDC y usado en cualquier escritorio del dominio al que
el usuario acceda. La desventaja de esta característica es que en algunos casos
los perfiles de los usuarios pueden ocupar un espacio excesivo en el disco duro.
Queremos usar esta característica para el tutorial así que la activamos.

El campo `Letra de unidad` asigna que letra sera usara para una unidad virtual
que contendrá el directorio personal del usuario.

El ultimo campo es `Grupo Samba`, con este parámetro puedes restringir los
usuarios que puedan entrar y compartir archivos al grupo seleccionado. En este
tutorial no queremos usar esta restricción así que los dejaremos establecido a
`Todos los usuarios`.


   
.. image:: images/pdc-howto/general-settings.png
   :scale: 80   
   :alt:    PDC general settings 



8. Configurando la política de contraseña del PDC
===================================================

Los administradores de dominio normalmente establecen algún tipo de política de
contraseñas debido a que sino los usuarios elegirán contraseñas débiles y
raramente las cambiaran.

En la pestaña `PDC` veremos tres parametros de contraseña para configurar:
El primero es `Mínima longitud de contraseña`. Queremos que los usuarios elijan
al menos una contraseña de 8 caracteres, así que elevamos el valor por defecto a
8.

El segundo es `Máxima duración de contraseña`, lo establecemos a 180 días para
asegurarnos que el usuario cambie su contraseña al menos dos veces por año. 

El ultimo es `Respetar historial de contraseña`, este parámetro hace que los
usuarios no puedan reusar contraseñas viejas, lo establecemos a `Mantener
historia para 5 contraseñas`, así los usuarios no pueden reutilizar sus cinco
ultimas contraseñas.

  
   
.. image:: images/pdc-howto/pdc-password-settings.png
   :scale: 80   
   :alt:    PDC password settings 



9. Guardando cambios
=======================================

Ahora que tenemos la configuración básica del PDC lista, necesitamos
guardar los cambios para establecerlos en el sistema. Para eso tenemos el botón
`Guardar cambios` en al esquina superior derecha, si tenemos cambios pendientes
estará coloreado en rojo sino en verde. Como hemos realizados cambio presentara
un rojo brillante, así que podemos pulsarlo.

.. image:: images/pdc-howto/06-savechanges.png
   :scale: 80   
   :alt:    Save changes button 


Después de pulsarlo llegaras a una pantalla que te presentara dos botones, uno
para salvar la configuración actual y otro para descartarla.
Si las descartas, la configuración sera revertida a los valores por defecto o,
si ya has guardado cambios anteriormente, a los últimos cambios
guardados. Queremos que se establezcan nuestros cambios así que pulsamos en el
botón `Guardar cambios`.

En algunos casos después de pulsar el botón, aparecerá una pantalla pidiendo
autorización para sobrescribir algunos archivos de configuración, si tu se la
deniegas eBox no podrá establecer tu configuración.

Después seras conducido a una pagina donde se muestra el progreso en el proceso
de establecer los cambios. Cuando termine, podrás ver un mensaje de *Cambios guardados*.


.. warning:: 
   Los cambios en usuarios y grupos son establecidos inmediatamente, así que no es
   necesario guardarlos y no es posible descartarlos.


10. Añadiendo ordenadores al PDC
=======================================

Ahora que tenemos nuestro PDC corriendo es el momento de añadir algunos
ordenadores al dominio.

Para ello necesitaremos conocer el nombre de nuestro dominio y el nombre de
usuario y contraseña de un usuario con derechos de administración. En nuestro
ejemplo el usuario *pdcadmin* es el adecuado.

La computadora a añadir deberá estar en la misma red local y debe tener un
Windows compatible con CIFS- (p.e. Windows XP Professional). La interfaz de red
por la que eBox conecte a esta red **no** debe estar marcada como externa. En las
siguientes instrucciones asumiremos que tienes un Windows XP Professional.

Entra en el sistema Windows y pulsa en `Mi PC -> Propiedades`, selecciona la
pestaña `Nombre de equipo`, pulsa en el botón `Cambiar`.


   
.. image:: images/pdc-howto/change-domain-button.png
   :scale: 80   
   :alt:    clicking on windows change domain button 

En la siguiente ventana, establece el nombre de dominio y pulsa *OK*.
   
   
.. image:: images/pdc-howto/ windows-change-domain.png
   :scale: 80   
   :alt:    setting domain name 


Una ventana de autenticación aparecerá, debes entrar como el usuario con
privilegios administrativos.
   
   
.. image:: images/pdc-howto/windows-change-domain-login.png
   :scale: 80   
   :alt:    login as user with administration priveleges 



Si todos los pasos fueron correctos aparecerá un mensaje de bienvenida al
dominio. Después de unirte al dominio, necesitaras reiniciar el ordenador. Tu
próxima entrada puede hacerse con un usuario del dominio.
   
   
.. image:: images/pdc-howto/pdc-login.png
   :scale: 80   
   :alt:    login with a domain user 

Si necesitas ayuda para unirte al dominio puedes leer la 
`documentación de Microsoft  <http://support.microsoft.com/kb/295017>`_
sobre esta operación.


11. Configurando recursos compartidos
=======================================

Ya tenemos nuestro dominio activo con sus usuarios, grupos y ordenadores. Ahora
queremos usar el servido de compartición de ficheros para facilitar que los
usuarios compartan ficheros entre ellos.

Hay tres tipos de recursos compartidos de archivos en eBox

#. Recursos compartidos de directorio personal de usuarios
#. Recursos compartidos de grupos
#. Recursos compartidos generales.

Los recursos compartidos de directorio personal de usuarios se crean
automáticamente para todos los usuarios. Esta disponible automáticamente como
una unidad virtual con la letra configurada en la pestaña de `Opciones
generales`. Solo el usuario puede acceder a su directorio personal así que es
útil para poder acceder a los mismos ficheros sin importar en que ordenador del
dominio se este usando.

Sin embargo, los recursos compartidos de grupo no son creados automáticamente,
debes ir a la pantalla de `Editar grupo` y establecer un nombre para el recurso.
Todos los miembros tienen acceso al recurso con la restricción de que no pueden
borrar o modificar ficheros que pertenezcan a otros usuarios.


   
   
.. image:: images/pdc-howto/group-sharing-directory.png
   :scale: 80   
   :alt:    form for setting of group sharing directory 


Respecto a la tercer categoría de recursos compartidos, eBox nos permite definir
múltiples recursos compartidos, cada uno con su propia lista de control de
acceso (ACL).

Para ilustrar esta característica, vamos a crear un recurso para la
documentación técnica del departamento de TI, todos los miembros del grupo *TI*
deben poder leer la documentación y el usuario *pdcadmin* debe tener permisos
para actualizarla.

Para crear el recurso compartido selecciona la pestaña *Recursos* que puedes
encontrar en la sección *Compartir ficheros* en el menú izquierdo. Veremos la
lista de recursos pero como todavía no hemos creado ninguno, estará vacía. Para
crear uno pulsaremos en *Añadir nueva*, esto te mostrara un formulario para
configurar el recurso.

El primer parámetro en el recurso es para activarlo o desactivarlo, lo dejamos
activado. Sin embargo, si quisiéramos  desactivarlo temporalmente este parámetro
seria útil.

Nombre de recurso es el nombre usado para identificarlo, en nuestro caso la
llamaremos *Documentación IT*.

El campo `comentario` puede ser usado para explicar mejor el propósito del
recurso. En nuestro caso, podemos escribir *Documentación para el departamento TI*.

Finalmente debemos elegir la ruta del recurso en el servidor, dos opciones son
posibles: `Directorio bajo eBox` o `Ruta de archivo`. La segunda esta pensada
para directorios ya existentes así que elegiremos `Directorio bajo eBox` y lo
llamaremos *itdoc*.


   
.. image:: images/pdc-howto/add-share.png
   :scale: 80   
   :alt:    Adding a new share 

Una vez el recurso definido deberemos elegirle un conjunto correcto de listas de
control de acceso. Para hacerlo iremos a la lista de recursos, buscaremos la
linea del recurso y haremos clic sobre el campo de `Control de Acceso`. Los
permisos pueden ser *leer*, *leer y escribir* y *administrador*. El permiso de
*administrador* permite borrar y modificar ficheros de otros usuarios así que
debe ser concedido con prudencia.

En nuestro ejemplo, concederemos un permiso de lectura al grupo de *TI* y uno de
*lectura y escritura* a `pdcadmin`. De esta manera los miembros del grupo podrán
leer la documentación y `pdcadmin` subirla, borrarla y editarla.


.. image:: images/pdc-howto/add-share-acl.png
   :scale: 80   
   :alt:    Adding a new ACL to a share 

.. note::
   Existen recursos especiales creados automáticamente por eBox cuyo acceso 
   solo es concedido a los usuarios con derechos de administración. Son
   `ebox-internal-backups` que contiene las copias de seguridad de eBox y
   `ebox-quarantine` que contiene los archivos infectados por virus.


12. Antivirus para los recursos compartidos
============================================


eBox puede detectar virus en los archivos de los recursos compartidos. La
comprobación se hace cuando el archivo es escrito o accedido así que puedes
estar seguro que todos los archivos en el recurso han sido comprobados por le
antivirus. Si se encuentra un archivo infectado es movido al recurso
`ebox-quarantine` que solo puede ser accedido por usuarios con derechos de
administración. Estos usuarios pueden examinar el recurso y elegir si borrar
dichos archivos o realizar otras acciones con ellos.

Para usar esta característica el modulo de antivirus debe estar activado, así
que si esta desactivado cambia su estado a activo. Las actualizaciones del
antivirus se bajan automáticamente cada hora por lo que no debes preocuparte por
ellas.

Para configurar el antivirus en los recursos ves a la pagina de `Compartir
archivos` y a la pestaña de antivirus. El parámetro de `detectar` determina si
los archivos deben ser comprobados o no.

Queremos que el antivirus examine los archivos así que activaremos este
parámetro en nuestro ejemplo. En la lista de `Recursos exentos de antivirus`,
podemos agregar recursos cuyos archivos no serán examinados sin importar el
valor del parámetro general.

   
   
.. image:: images/pdc-howto/antivirus.png
   :scale: 80   
   :alt:    Antivirus settings 



13. Accediendo a los recursos
=======================================

Tenemos nuestros recursos definidos así que quedemos acceder a ellos ahora. Pero
antes de acceder, aseguremos de que hemos salvado los últimos cambios en la
configuración, como se explico en la sección `9. Guardando cambios`_.

Cuando entres en un ordenador del dominio con un usuario del dominio podrás
acceder a los recursos usando la ventana `Toda la red`, para acceder a esta
ventana haz clic en `Mi PC -> Mis sitios de red` y luego en el acceso que hay
en el panel izquierdo `Otros sitios`.

   
   
.. image:: images/pdc-howto/domain-computers.png
   :scale: 80   
   :alt:    Domain network view 

Después de seleccionar el servidor eBox, todos los recursos visibles por el
usuario aparecerán. Puedes intentar acceder a un recurso haciendo clic, si el
usuario tiene acceso de lectura se abrirá una ventana de navegador con los
contenidos del recurso.

.. image:: images/pdc-howto/domain-server-shares.png
   :scale: 80   
   :alt:    Shares in PDC server 


Adicionalmente el directorio personal del usuario sera mapeado a una unidad
virtual con la letra establecida en la configuración del PDC.



.. note:: En un sistema GNU/Linux puedes usar el programa *smbclient* para
          acceder a los recursos. Puedes encontrar una guía para usarlo `aquí
          <http://tldp.org/HOWTO/SMB-HOWTO-8.html>`_. Otra opción es usar un
          navegador de archivos con capacidades SMB como los suministrados por
          defecto en KDE y Gnome.

Si tienes el antivirus activado puedes probarlo intentando subir un archivo
infectado. Para pruebas recomendamos el uso del `archivo de prueba EICAR
<http://www.eicar.org/anti_virus_test_file.htm>`_ ya que es inofensivo.



14. Script de logon
=======================================

eBox soporta el uso de scripts de logon. Este script sera descargado y ejecutado
cada vez que un usuario entre en un ordenador perteneciente al dominio. 

Cuando escribas un script de este tipo tienes que tener en cuenta que sera
ejecutado en el ordenador donde el usuario halla entrado, así que solo debes
programar ordenes que puedan ser ejecutadas en cualquier ordenador del dominio.

Además, sera un sistema Windows así que tienes que asegurarte que el archivo
esta escrito con los caracteres de retorno de carro y fin de linea. Para
asegurar esto puedes escribirlo en un ordenador Windows o usar la herramienta de
Unix *flip* para convertir entre los dos formatos.

Una vez hallas escrito tu script de logon deberas guardarlo como *logon.bat* en
el directorio `/home/samba/netlogons` de tu servidor eBox.

Para ofrecer un ejemplo, mostraremos un script de logon que mapea un recurso
llamado `horarios`, que contendría los horarios de la empresa, a la unidad
`Y:`. Recuerda que antes de ejecutar este script deberas crear el recurso y dar
los permisos adecuados para acceder al recurso.
::
    # script de logon para mapear recurso de horarios
    echo "Mapeando horarios a unidad Y: ..."
    net use y: \\ebox-server\horarios

15. Fin de trayecto
=======================================

Esto es todo por hoy. Espero que la información y ejemplos de este tutoria te
ayuden a usar eBox como Controlador Primario de Dominio de Windows y servidor de archivos.

Me gustaría agradecerle a Falko Timme que escribiera un tutorial de servidor de
archivos para una versión anterior de eBox, su texto ha servido de punto de partida de
este documento.


