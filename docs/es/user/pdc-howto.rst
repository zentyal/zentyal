Usando eBox como Controlador Primario de Dominio
--------------------------------------------------

.. sectionauthor:: Javier Amor García   <jamor@ebox-platform.com>
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>

`eBox Platform <http://www.ebox-platform.com>`_ es un servidor de código abierto
para pequeñas y medianas empresas que te permite gestionar tus servicios, tales
como cortafuegos,  DHCP, DNS, VPN, *proxy*, IDS, correo electrónico, ficheros e impresoras
compartidas, VoIP, IM y muchos más. Esta funcionalidades están fuertemente
integradas, automatizando tareas, evitando errores y ahorrando tiempo a los
administradores de sistemas.

Este tutorial te mostrará, paso a paso, como usar eBox actuando como
un Controlador Primario de Dominio (PDC) de Windows. Cuando lo cabemos
estará usando eBox Platform para la gestión de usuarios y recursos
compartidos de tu dominio Windows.

1. Instalando el servidor eBox
==============================

La instalación puede hacerse de dos maneras distintas:

- Usando el instalador de la eBox Platform (recomendado).
- Usando una instalación ya existente de Ubuntu TLS Server.

En el segundo caso, necesitarás añadir los `repositorios
<http://launchpad.net/~ebox/+archive/1.4>`_ de eBox Platform a
`/etc/apt/sources.list` e instalar los paquetes que te interesen. [#]_

.. [#] La guía completa de la instalación se encuentra en
       http://trac.ebox-platform.com/wiki/Document/Documentation/InstallationGuide

De todas maneras, en el primer caso la instalación y despliegue son mas fáciles
ya que todas las dependencias están en un único disco y  además se realizan
preconfiguraciones durante el proceso de instalación. Por esta razón,
se usará este método en el tutorial. 

.. figure:: images/pdc-howto/eBox-installer.png
   :scale: 80
   :alt: Instalador de eBox Platform

   Instalador de eBox Platform

El instalador de eBox Platform está basado en el instalador de Ubuntu y aquellos
que estén familiarizados con este último encontrarán el proceso muy similar. En
este documento no cubrimos la instalación de Ubuntu, pero si tienes dudas puedes
consultar su `documentación oficial de instalación
<https://help.ubuntu.com/8.04/serverguide/C/installation.html>`_.

Una vez la instalación del sistema base haya finalizado, el sistema se
reiniciaría y dará comienzo el proceso de instalación de eBox. Primero, te
preguntará sobre que componentes *software* deben ser instalados. Hay dos maneras de
seleccionar los componentes que quieras desplegar en tu sistema, en este caso
elegiremos el método **simple**.

.. figure:: images/pdc-howto/package-selection-method.png
   :scale: 80
   :alt: Selección del método de instalación

   Selección del método de instalación

Después de escoger el método **simple**, se te mostrará una lista de
perfiles de *software*. En nuestro caso tan sólo seleccionaremos el
perfil **Oficina** que contiene todos los componentes necesarios para
el PDC. Esta selección no va a ser inalterable y más adelante puedes
instalar o eliminar paquetes según dicten tus necesidades.

.. figure:: images/pdc-howto/profiles.png
   :scale: 60
   :alt: Selección de perfiles

   Selección de perfiles

Una vez seleccionados los componentes a instalar, una barra de progreso te
irá mostrando el estado del proceso de instalación.
   
.. figure:: images/pdc-howto/installing-eBox.png
   :scale: 80
   :alt: Instalando eBox Platform

   Instalando eBox Platform

Cuando la instalación termine, se te pedirá introducir una contraseña para
acceder a el interfaz *web* de eBox Platform.

.. figure:: images/pdc-howto/password.png
   :scale: 80   
   :alt: Introducir la contraseña para acceder al interfaz *web*

   Introducir la contraseña para acceder al interfaz *web*

Necesitarás confirmar la contraseña en el siguiente diálogo.

.. figure:: images/pdc-howto/repassword.png
   :scale: 80      
   :alt: Confirmar la contraseña de acceso al interfaz *web*

   Confirmar la contraseña de acceso al interfaz *web*

Después el instalador intentará preconfigurar algunos parámetros básicos. 

Primero, te preguntará si alguna de tus interfaces es externa, es decir
conectada a una red que no sea interna, por ejemplo, la tarjeta conectada al
*router* que da acceso a *Internet*. Se aplicarán políticas estrictas al trafico
entrante por interfaces externas. Dependiendo del papel que juegue el servidor,
i.e. situado dentro de tu red interna proveyendo únicamente servicios locales,
es posible que no haya ninguna interfaz externa.

.. figure:: images/pdc-howto/select-external-iface.png
   :scale: 80   
   :alt: Selección del interfaz externo

   Selección del interfaz externo

A continuación, te preguntará por un nombre de dominio virtual de correo. Como no
vamos a usar el servicio de correo en este tutorial, puedes introducir cualquier
nombre que te convenga.
   
.. figure:: images/pdc-howto/vmaildomain.png
   :scale: 80   
   :alt: Establecer el nombre del dominio virtual de correo

   Establecer el nombre del dominio virtual de correo

Una vez respondidas estas preguntas, los módulos que hayas instalados
serán preconfigurados.
   
.. figure:: images/pdc-howto/preconfiguring-ebox.png
   :scale: 80   
   :alt: Preconfigurando los paquetes de eBox

   Preconfigurando los paquetes de eBox

Cuando este proceso se complete, un mensaje te informará sobre como conectar al
interfaz *web* de eBox Platform.
   
.. figure:: images/pdc-howto/ebox-ready-to-use.png
   :scale: 80   
   :alt: Mensaje de eBox preparada para usarse 

   Mensaje de eBox preparada para usarse

2. Entrando al interfaz *web*
=============================

Ya estás listo para entrar por primera vez al interfaz *web* de eBox.  Apunta tu
navegador hacia `https://dirección/` siendo la dirección aquella que te
suministro el instalador en el paso anterior.

Como el servidor eBox tiene un nuevo certificado auto-firmado, tu navegador
probablemente te preguntará si puede considerarlo de confianza. Haz que tu
navegador confíe en él para poder continuar.

Después, te será mostrada la pantalla de acceso, para entrar introduce
la contraseña de administración de eBox que estableciste durante el
proceso de instalación.
   
.. figure:: images/pdc-howto/01-login.png
   :scale: 80   
   :alt: Pantalla de entrada

   Pantalla de entrada

Después de entrar, se te mostrará el sumario del estado de los
servicios del servidor.
   
.. figure:: images/pdc-howto/02-homepage.png
   :scale: 80   
   :alt: Pantalla de sumario

   Pantalla de sumario


3. Activando y desactivando módulos
===================================

El siguiente paso es desactivar los módulos que no son necesarios para
el servidor PDC. Para hacerlo en el menú de la izquierda selecciona
:menuselection:`Estado del modulo`. En dicha pagina se te mostrará la
lista de los módulos de eBox instalados y una casilla para activarlos
o desactivarlos.
   
.. figure:: images/pdc-howto/module-status.png
   :scale: 80   
   :alt: Página del estado de los módulos

   Página del estado de los módulos

Por defecto, todos los módulos instalados están activados pero para
hacer un uso más eficiente de los recursos de tu sistema, puedes
desactivar los módulos que no son necesitados por el PDC. Los módulos
que necesita el PDC son los siguientes:

-  Red
-  Registros
-  Usuarios y Grupos
-  Compartición de Ficheros
-  Antivirus

Puedes desactivar cualquier otro modulo para ahorrar recursos de tu sistema.

5. Creando grupos
=================

Puedes necesitar grupos de usuarios en tu dominio. Para crear grupos,
en el menú de la izquierda selecciona :menuselection:`Usuarios y
Grupos -> Añadir grupo`. Se te solicitará un :guilabel:`nombre` para el grupo y
opcionalmente podrás establecer una :guilabel:`descripción` para el mismo.
   
.. figure:: images/pdc-howto/add-group.png
   :scale: 80   
   :alt: Formulario para añadir un grupo

   Formulario para añadir un grupo

Puedes pulsar el botón de :guilabel:`Añadir y Editar` o de
:guilabel:`Añadir` para crear el grupo. Para este tutorial crearemos
el grupo *TI*. También puedes crear cualquier grupo que veas necesario
para tu dominio.

6. Creando usuarios
===================

Para crear tus usuarios de dominio, selecciona en el menú izquierdo
:menuselection:`Usuarios y Grupos --> Añadir usuario`. Se te mostrará
un formulario para añadir el nuevo usuario con los siguientes campos:

:guilabel:`Nombre de usuario`:
   Nombre con el que será identificado el usuario por el
   sistema de manera única.

:guilabel:`Nombre`:
   Nombre del usuario.

:guilabel:`Apellidos`:
   Apellido del usuario.

:guilabel:`Comentario`:
   Campo para añadir un comentario al usuario.

:guilabel:`Contraseña` y :guilabel:`Confirmar contraseña`:
   Contraseña para el usuario, podrá cambiarla después de conectar al
   dominio. Posteriormente veremos como definir políticas de
   contraseñas.

:guilabel:`Grupo`:
   Grupo primario del usuario. Después el usuario puede unirse a mas
   grupos.
   
.. figure:: images/pdc-howto/add-user.png
   :scale: 80   
   :alt: Formulario para añadir un usuario 

   Formulario para añadir un usuario

Para este tutorial crearemos un usuario llamado **pdcadmin**. Puedes
rellenar los otros campos con valores que consideres apropiados. Pulsa
en :guilabel:`Añadir y editar` para ser redirigido a la pagina
:guilabel:`Editar usuario`.

En la página de :guilabel:`Editar usuario` hay parámetros de PDC,
están bajo la cabecera :guilabel:`Cuenta de compartición de ficheros o
de PDC`.

Puedes activar o desactivar la cuenta, una cuenta desactivada no puede entrar ni
ser usada en el dominio. Dejaremos nuestra cuenta de usuario
activada. Puedes establecer este parámetro activado por defecto usando
:menuselection:`Usuarios y Grupos --> Plantilla de Usuario por Defecto`.

También es posible otorgar permisos administrativos al usuario. Un usuario con
permisos administrativos puede añadir ordenadores al dominio, por lo que
necesitarás al menos un usuario con estos permisos. Por esta razón, activaremos
los permisos administrativos en el usuario **pdcadmin**.

Hay otro campo que nos permite cambiar la cuota de disco para el usuario. No nos
hace falta modificar ese campo ahora.
   
.. figure:: images/pdc-howto/pdc-user-settings.png
   :scale: 80   
   :alt: Parámetros relacionados con el PDC

   Parámetros relacionados con el PDC

Ahora puedes crear mas cuentas de usuarios para tus usuarios normales. Solo
necesitan una cuenta activada sin derechos de administración. Si crees que su
cuota de disco es demasiada pequeña o grande puedes editarla también.

7. Configurando parámetros generales de PDC
============================================

Para configurar los parámetros generales de PDC y compartición de ficheros, en
el menú izquierdo selecciona :menuselection:`Compartir ficheros`.

En la pestaña :guilabel:`Parámetros generales` marcaremos la casilla
:guilabel:`Activar PDC`. También puedes cambiar el :guilabel:`nombre de dominio`
de su valor por defecto a uno que tenga sentido para tu organización o
dominio. En el tutorial usaremos **ebox** como nombre de dominio.

Asimismo puedes cambiar el :guilabel:`nombre de NetBIOS`. Este será el nombre que
identificará al servidor cuando use el protocolo NetBIOS. Este nombre no debe
ser el mismo que el dominio, sin considerar mayúsculas, o podremos tener
problemas de conexión. Usaremos **ebox-server** como nombre de NetBIOS.

En el campo :guilabel:`Descripción` puedes introducir un texto para
identificar mejor el dominio.

En campo :guilabel:`Limite de cuota` es el valor que se asignara en
cuota de disco a los nuevos usuarios.

El control :guilabel:`Activar perfiles remotos` controla si el perfil
de escritorio del usuario es guardado en el PDC y usado en cualquier
escritorio del dominio al que el usuario acceda. La desventaja de esta
característica es que en algunos casos los perfiles de los usuarios
pueden ocupar un espacio excesivo en el disco duro. Queremos usar
esta característica para el tutorial así que la activamos.

El campo :guilabel:`Letra de unidad` asigna que letra será usada para
una unidad virtual que contendrá el directorio personal del usuario.

El ultimo campo es :guilabel:`Grupo Samba`, con este parámetro puedes
restringir los usuarios que puedan entrar y compartir ficheros al
grupo seleccionado. En este tutorial no queremos usar esta restricción
así que los dejaremos con el valor por defecto de :guilabel:`Todos los usuarios`.
   
.. figure:: images/pdc-howto/general-settings.png
   :scale: 80   
   :alt: Configuración general del PDC

   Configuración general del PDC

8. Configurando la política de contraseña del PDC
=================================================

Los administradores de dominio normalmente establecen algún tipo de
política de contraseñas debido a que sino los usuarios elegirán
contraseñas débiles y raramente las cambiarían.

En la pestaña :guilabel:`PDC` hay tres parámetros de contraseña para
configurar: El primero es :guilabel:`Mínima longitud de
contraseña`. Queremos que los usuarios elijan al menos una contraseña
cuya longitud sea de 8 caracteres, así que elevamos el valor hasta 8.

El segundo es :guilabel:`Máxima duración de contraseña`, lo
establecemos a 180 días para asegurarnos que el usuario cambie su
contraseña al menos dos veces por año.

El ultimo es :guilabel:`Respetar historial de contraseña`, este
parámetro hace que los usuarios no puedan reusar contraseñas viejas,
lo establecemos a *Mantener historia para 5 contraseñas*, así los
usuarios no pueden reutilizar sus cinco últimas contraseñas.
   
.. figure:: images/pdc-howto/pdc-password-settings.png
   :scale: 80   
   :alt: Configuración de las contraseñas en el PDC

   Configuración de las contraseñas en el PDC

.. _saving-changes-sec:

9. Guardando cambios
====================

Ahora que tenemos la configuración básica del PDC lista, necesitamos
guardar los cambios para establecerlos en el sistema. Para eso,
tenemos el botón :guilabel:`Guardar cambios` en al esquina superior
derecha, si tenemos cambios pendientes estará coloreado en rojo sino
en verde. Como hemos realizados cambio presentará un rojo brillante,
así que podemos pulsarlo.

.. figure:: images/pdc-howto/06-savechanges.png
   :scale: 80   
   :alt: Botón de guardar cambios

   Botón de guardar cambios

Después de pulsarlo, llegarás a una pantalla que te presentará dos
botones, uno para guardar la configuración actual y otro para
descartarla.  Si las descartas, la configuración sera revertida a los
valores por defecto o, si ya has guardado cambios anteriormente, a los
últimos cambios guardados. Queremos que se establezcan nuestros
cambios así que pulsamos en el botón :guilabel:`Guardar cambios`.

En algunos casos, después de pulsar el botón, aparecerá una pantalla pidiendo
autorización para sobrescribir algunos ficheros de configuración, si se
deniega eBox, no podrá establecer tu configuración.

Después serás conducido a una página donde se muestra el progreso en
el proceso de establecer los cambios. Cuando termine, podrás ver un
mensaje de *Cambios guardados*.

.. warning:: 
   Los cambios en usuarios y grupos son establecidos inmediatamente, así que no es
   necesario guardarlos y no es posible descartarlos.


10. Añadiendo ordenadores al PDC
================================

Ahora que tenemos nuestro PDC en funcionamiento, es el momento de
añadir algunos ordenadores al dominio.

Para ello, necesitaremos conocer el nombre de nuestro dominio y el nombre de
usuario y contraseña de un usuario con derechos de administración. En nuestro
ejemplo el usuario **pdcadmin** es el adecuado.

El ordenador a añadir deberá estar en la misma red local y debe tener un
Windows compatible con CIFS (p.e. Windows XP Professional). La interfaz de red
por la que eBox conecte a esta red **no** debe estar marcada como externa. En las
siguientes instrucciones, asumiremos que tienes un Windows XP Professional.

Entra en el sistema Windows y pulsa en :menuselection:`Mi PC -->
Propiedades`, selecciona la pestaña :guilabel:`Nombre de equipo`, pulsa en el
botón :guilabel:`Cambiar`.
  
.. figure:: images/pdc-howto/change-domain-button.png
   :scale: 80   
   :alt: Pulsando en el botón de cambiar el dominio de Windows

En la siguiente ventana, establece el :guilabel:`nombre de dominio` y
pulsa :guilabel`OK`.
   
.. figure:: images/pdc-howto/ windows-change-domain.png
   :scale: 80   
   :alt: Estableciendo el nombre de dominio

   Estableciendo el nombre de dominio

Una ventana de autenticación aparecerá, debes entrar como el usuario con
privilegios administrativos.
   
.. figure:: images/pdc-howto/windows-change-domain-login.png
   :scale: 80   
   :alt: Entrar como usuario con privilegios administrativos
   
   Entrar como usuario con privilegios administrativos

Si todos los pasos fueron correctos aparecerá un mensaje de bienvenida al
dominio. Después de unirte al dominio, necesitaras reiniciar el ordenador. Tu
próxima entrada puede hacerse con un usuario del dominio.
   
.. figure:: images/pdc-howto/pdc-login.png
   :scale: 80   
   :alt: Entrar con un usuario del dominio

Si necesitas ayuda para unirte al dominio puedes leer la 
`documentación de Microsoft  <http://support.microsoft.com/kb/295017>`_
sobre esta operación.


11. Configurando recursos compartidos
=====================================

Ya tenemos nuestro dominio activo con sus usuarios, grupos y ordenadores. Ahora
queremos usar el servido de compartición de ficheros para facilitar que los
usuarios compartan ficheros entre ellos.

Hay tres tipos de recursos compartidos de ficheros en eBox:

#. Recursos compartidos de directorio personal de usuarios
#. Recursos compartidos de grupos
#. Recursos compartidos generales.

Los recursos compartidos de directorio personal de usuarios se crean
automáticamente para todos los usuarios. Está disponible
automáticamente como una unidad virtual con la letra configurada en la
pestaña de :guilabel:`Opciones generales`. Sólo el usuario puede
acceder a su directorio personal, así que es útil para poder acceder a
los mismos ficheros sin importar en que ordenador del dominio se esté
usando.

Sin embargo, los recursos compartidos de grupo no son creados
automáticamente, debes ir a la pantalla de :menuselection:`Usuarios y
Grupos --> Editar grupo` y establecer un nombre para el recurso.
Todos los miembros tienen acceso al recurso con la restricción de que
no pueden borrar o modificar ficheros que pertenezcan a otros
usuarios.
   
.. figure:: images/pdc-howto/group-sharing-directory.png
   :scale: 80   
   :alt: Formulario para establecer el directorio de compartición para el grupo

   Formulario para establecer el directorio de compartición para el grupo

Respecto a la tercer categoría de recursos compartidos, eBox nos permite definir
múltiples recursos compartidos, cada uno con su propia *lista de control de
acceso* (ACL).

Para ilustrar esta característica, vamos a crear un recurso para la
documentación técnica del departamento de TI, todos los miembros del grupo **TI**
deben poder leer la documentación y el usuario **pdcadmin** debe tener permisos
para actualizarla.

Para crear el recurso compartido selecciona la pestaña
:menuselection:`Compartir ficheros --> Recursos`. Veremos la lista de
recursos pero como todavía no hemos creado ninguno, estará vacía. Para
crear uno pulsaremos en :guilabel:`Añadir nueva`, esto te mostrará un formulario
para configurar el recurso.

El primer parámetro en el recurso es para activarlo o desactivarlo, lo dejamos
activado. Sin embargo, si quisiéramos  desactivarlo temporalmente este parámetro
seria útil.

:guilabel:`Nombre de recurso` es el nombre usado para identificarlo, en nuestro caso la
llamaremos *Documentación TI*.

El campo :guilabel:`comentario` puede ser usado para explicar mejor el propósito del
recurso. En nuestro caso, podemos escribir *Documentación para el departamento TI*.

Finalmente, debemos elegir la ruta del recurso en el servidor, dos
opciones son posibles: :guilabel:`Directorio bajo eBox` o
:guilabel:`Ruta de fichero`. La segunda está pensada para directorios
ya existentes así que elegiremos `Directorio bajo eBox` y lo
llamaremos **tidoc**.
   
.. figure:: images/pdc-howto/add-share.png
   :scale: 80   
   :alt: Añadiendo un nuevo recurso

   Añadiendo un nuevo recurso

Una vez el recurso definido, deberemos elegirle un conjunto correcto
de listas de control de acceso. Para hacerlo iremos a la lista de
recursos, buscaremos la linea del recurso y haremos clic sobre el
campo de :guilabel:`Control de Acceso`. Los permisos pueden ser
*leer*, *leer y escribir* y *administrador*. El permiso de
*administrador* permite borrar y modificar ficheros de otros usuarios
así que debe ser concedido con prudencia.

En nuestro ejemplo, concederemos un permiso de lectura al grupo de *TI* y uno de
*lectura y escritura* a **pdcadmin**. De esta manera los miembros del grupo podrán
leer la documentación y **pdcadmin** subirla, borrarla y editarla.

.. figure:: images/pdc-howto/add-share-acl.png
   :scale: 80   
   :alt: Añadiendo una nueva ACL a un recurso

   Añadiendo una nueva ACL a un recurso

.. note::
   Existen recursos especiales creados automáticamente por eBox cuyo acceso 
   sólo es concedido a los usuarios con derechos de administración. Son
   `ebox-internal-backups` que contiene las copias de seguridad de eBox y
   `ebox-quarantine` que contiene los archivos infectados por virus.


12. Antivirus para los recursos compartidos
===========================================

Se puede detectar virus en los ficheros de los recursos compartidos
con eBox. La comprobación se hace cuando el fichero es escrito o
accedido así que puedes estar seguro que todos los ficheros en el
recurso han sido comprobados por le antivirus. Si se encuentra un
archivo infectado es movido al recurso *ebox-quarantine* que sólo
puede ser accedido por usuarios con derechos de administración. Estos
usuarios pueden examinar el recurso y elegir si borrar dichos ficheros
o realizar otras acciones con ellos.

Para usar esta característica el módulo de **antivirus** debe estar activado, así
que si esta desactivado cambia su estado a activo. Las actualizaciones del
antivirus se bajan automáticamente cada hora por lo que no debes preocuparte por
ellas.

Para configurar el antivirus en los recursos ves a la pagina de
:menuselection:`Compartir ficheros --> Antivirus`. El parámetro de
:guilabel:`detectar` determina si los ficheros deben ser comprobados o
no.

Queremos que el antivirus examine los ficheros así que activaremos
este parámetro en nuestro ejemplo. En la lista de :guilabel:`Recursos
exentos de antivirus`, podemos agregar recursos cuyos ficheros no
serán examinados sin importar el valor del parámetro general.
   
.. figure:: images/pdc-howto/antivirus.png
   :scale: 80   
   :alt: Configuración de antivirus

   Configuración de antivirus


13. Accediendo a los recursos
=============================

Tenemos nuestros recursos definidos así que quedemos acceder a ellos ahora. Pero
antes de acceder, aseguremos de que hemos salvado los últimos cambios en la
configuración, como se explico en la sección :ref:`saving-changes-sec`.

Cuando entres en un ordenador del dominio con un usuario del dominio
podrás acceder a los recursos usando la ventana :guilabel:`Toda la
red`, para acceder a esta ventana, haz clic en :menuselection:`Mi PC
--> Mis sitios de red` y luego en el acceso que hay en el panel
izquierdo :guilabel:`Otros sitios`.
   
.. figure:: images/pdc-howto/domain-computers.png
   :scale: 80   
   :alt: Vista de la red del dominio

   Vista de la red del dominio

Después de seleccionar el servidor eBox, todos los recursos visibles por el
usuario aparecerán. Puedes intentar acceder a un recurso haciendo clic, si el
usuario tiene acceso de lectura se abrirá una ventana de navegador con los
contenidos del recurso.

.. figure:: images/pdc-howto/domain-server-shares.png
   :scale: 80   
   :alt: Recursos en un servidor PDC
   
   Recursos en un servidor PDC

Además, el directorio personal del usuario será mapeado a una unidad
virtual con la letra establecida en la configuración del PDC.

.. note:: En un sistema GNU/Linux puedes usar el programa *smbclient* para
          acceder a los recursos. Puedes encontrar una guía para usarlo `aquí
          <http://tldp.org/HOWTO/SMB-HOWTO-8.html>`_. Otra opción es usar un
          navegador de archivos con capacidades SMB como los suministrados por
          defecto en KDE y Gnome.

Si tienes el antivirus activado puedes probarlo intentando subir un
fichero infectado. Para pruebas recomendamos el uso del `archivo de
prueba EICAR <http://www.eicar.org/anti_virus_test_file.htm>`_ ya que
es inofensivo.

14. *Script* de entrada
=======================

Con eBox se permite el uso de **scripts de entrada**. Este *script* será
descargado y ejecutado cada vez que un usuario entre en un ordenador
perteneciente al dominio.

Cuando escribas un *script* de este tipo tienes que tener en cuenta que
será ejecutado en el ordenador donde el usuario haya entrado, así que
sólo debes programar órdenes que puedan ser ejecutadas en cualquier
ordenador del dominio.

Además, será un sistema Windows así que tienes que asegurarte que el
fichero está escrito con los caracteres de retorno de carro y fin de
linea. Para asegurar esto puedes escribirlo en un ordenador Windows o
usar la herramienta de Unix **flip** para convertir entre los dos
formatos.

Una vez hayas escrito tu *script* de entrada deberás guardarlo como
**logon.bat** en el directorio `/home/samba/netlogons` de tu servidor
eBox.

Para ofrecer un ejemplo, mostraremos un *script* de entrada que mapea
un recurso llamado **horarios**, que contendría los horarios de la
empresa, a la unidad **Y:**. Recuerda que antes de ejecutar este
*script* deberás crear el recurso y dar los permisos adecuados para
acceder al recurso.
::

    # script de logon para mapear recurso de horarios
    echo "Mapeando horarios a unidad Y: ..."
    net use y: \\ebox-server\horarios

15. Fin de trayecto
===================

Esto es todo por hoy. Espero que la información y ejemplos de este
tutorial te ayuden a usar eBox como Controlador Primario de Dominio de
Windows y servidor de archivos.

Me gustaría agradecerle a Falko Timme que escribiera un tutorial de
servidor de ficheros para una versión anterior de eBox, su texto ha
servido de punto de partida de este documento.


