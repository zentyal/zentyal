Servicio de directorio (LDAP)
*****************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Javier Uruen <juruen@ebox-platform.com>

Para almacenar y organizar la información relativa a organizaciones (en nuestro
caso, usuarios y grupos) se utilizan los **servicios de directorio**. Estos
permiten a los administradores de la red manejar el acceso a los recursos por
parte de los usuarios añadiendo una capa de abstracción entre ambos.
Este servicio da una interfaz de acceso a la información. También
actúa como una autoridad central y común a través de la cual los usuarios se
pueden autenticar de manera segura.

Se podría hacer la analogía entre un servicio de directorio y las páginas
amarillas. Entre sus características destacan:

* La información es muchas más veces leída que escrita.
* Estructura jerárquica que simula la arquitectura de las organizaciones.
* A cada clase de objeto, estandarizada por la IANA [#]_, se le definen unas
  propiedades sobre las cuales se pueden definir listas de control de acceso
  (ACLs).

.. [#] *Internet Assigned Numbers Authority* (IANA) es una
   organización que se encarga de la asignación de direcciones IP públicas,
   nombres de dominio de máximo nivel (TLD), etc. http://www.iana.org/

Existen múltiples implementaciones del servicio de directorio entre
las que destacamos NIS, OpenLDAP, ActiveDirectory, etc. eBox usa
**OpenLDAP** como servicio de directorio con tecnología *Samba* para
controlador de dominios *Windows* además de para compartir ficheros e
impresoras.

Usuarios y grupos
=================

Normalmente, en la gestión de una organización de mayor o menor tamaño
existe la concepción de **usuario** o **grupo**. Para facilitar la
tarea de administración de recursos compartidos se diferencia entre
entre usuarios y grupos de ellos. Cada uno de los cuales puede tener
diferentes privilegios con respecto a los recursos de la organización.

Gestión de los usuarios y grupos en eBox
----------------------------------------

Modos
^^^^^

Como se ha explicado, eBox está diseñada de manera modular, permitiendo
al administrador distribuir los servicios entre varias máquinas de la red.
Para que esto sea posible, el módulo de **usuarios y grupos** puede
configurarse siguiendo una arquitectura maestro/esclavo para compartir
usuarios entre las diferentes eBoxes.

Por defecto y a no ser que se indique lo contrario en el menú
:menuselection:`Users and Groups --> Mode`, el módulo se configurará
como un directorio LDAP maestro y el Nombre Distinguido (DN) del directorio
se establecerá de acuerdo al nombre de la máquina. Si se desea configurar
un DN diferente, se puede hacer en la entrada de texto :guilabel:`LDAP DN`.

.. image:: images/directory/users-mode.png
   :scale: 80

Otras eBoxes pueden ser configuradas para usar un maestro como fuente de sus
usuarios, convirtiéndose así en directorios esclavos. Para hacer esto, se
debe seleccionar el modo *esclavo* en
:menuselection:`Users and Groups --> Mode`. La configuración del esclavo
necesita dos datos más, la IP o nombre de máquina del directorio maestro
y su clave de LDAP. Esta clave no es la de eBox, sino una generada
automáticamente al activar el módulo **usuarios y grupos**. Su valor puede ser
obtenido en el campo **Contraseña** de la opción de menú
:menuselection:`Users and Groups --> LDAP Info` en la eBox maestra.

.. image:: images/directory/ldap-info.png
   :scale: 80

Hay un requisito más antes de registrar una eBox esclava en una eBox maestra.
El maestro debe de ser capaz de resolver el nombre de máquina del esclavo
utilizando DNS. Hay varias maneras de conseguir esto. La más sencilla es añadir
una entrada para el esclavo en el fichero */etc/hosts* del maestro. Otra opción
es configurar el servicio DNS en eBox, incluyendo el nombre de máquina del
esclavo y la dirección IP.

Si el módulo cortafuegos está habilitado en la eBox maestra, debe ser
configurado de manera que permita el tráfico entrante de los esclavos. Por
defecto, el cortafuegos prohibe este tráfico, por lo que es necesario
asegurarse de hacer los ajustes necesarios en el mismo antes de proseguir.

Una vez todos los parámetros han sido establecidos y el nombre de máquina
del esclavo puede ser resuelto desde el maestro, el esclavo puede registrarse
en la eBox maestra habilitando el módulo de **usuarios y grupos** en
:menuselection:`Estado de los módulos`.

Los esclavos crean una réplica del directorio maestro cuando se registran por
primera vez, que se mantiene actualizada automáticamente cuando se añaden
nuevos usuarios y grupos. Se puede ver la lista de esclavos en el menú
:menuselection:`Usuarios y grupos --> Estado de los esclavos` de la eBox
maestra.

.. image:: images/directory/slave-status.png
   :scale: 80

Los módulos que utilizan usuarios como por ejemplo **correo* y **samba** pueden
instalarse ahora en los esclavos y utilizarán los usuarios disponibles en la
eBox maestra. Algunos módulos necesitan que se ejecuten algunas acciones
cuando se añaden usuarios, como por ejemplo **samba**, que necesita crear los
directorios de usuario. Para hacer esto, el maestro notifica a los esclavos
sobre nuevos usuarios y grupos cuando son creados, dando la oportunidad a los
esclavos de ejecutar las acciones apropiadas.

Puede haber problemas ejecutando estas acciones en ciertas circunstancias, por
ejemplo si uno de los esclavos está apagado. En ese caso el maestro recordará
que hay acciones pendientes que deben realizarse y lo reintentará
periódicamente. El usuario puede comprobar también el estado de los esclavos en
:menuselection:`Users and Groups --> Slave Status` y forzar el reintento de las
acciones manualmente. Desde esta sección también es posible borrar un esclavo.

Hay una importante limitación en la arquitectura maestro/esclavo actual. El
maestro eBox no puede tener instalados módulos que dependan de
**usuarios y grupos**, como por ejemplo **samba** o **mail**. Si el maestro
tiene alguno de estos módulos instalados, deben ser desinstalados antes de
intentar registrar un esclavo en él.

Si en algún momento se desea cambiar el modo de operación del módulo
**usuarios y grupos**, se puede hacer utilizando el script
**ebox-usersandgroups-reinstall**. Este script se puede encontrar en
**/usr/share/ebox-usersandgroups/** y cuando se ejecuta elimina completamente
el contenido del directorio LDAP, borrando todos los usuarios y grupos actuales
y reinstalando desde cero un directorio vacío que puede ser configurado en un
modo diferente.

Creación de usuarios y grupos
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Se puede crear un grupo desde el menú :menuselection:`Usuarios y Grupos -->
Grupos`. Un grupo se identifica por su nombre, y puede contener
una descripción.

.. image:: images/directory/01-groupadd.png
   :scale: 80

A través de :menuselection:`Usuarios y Grupos --> Grupos` se pueden ver
todos los grupos existentes para poder editarlos o borrarlos.

Mientras se edita un grupo, se pueden elegir los usuarios que pertenecen al
grupo, además de la información que tiene que ver con aquellos módulos de eBox
instalados que poseen alguna configuración específica para los grupos de
usuarios.

.. image:: images/directory/02-groupedit.png
   :scale: 80

Entre otras cosas con grupos de usuarios es posible:

* Disponer de un directorio compartido entre los usuarios de un grupo.
* Dar permisos sobre una impresora a todos los usuarios de un grupo.
* Crear un alias de cuenta de correo que redirija a todos los usuarios de un
  grupo.
* Asignar permisos de acceso a las distintas aplicaciones de eGroupware a
  todos los usuarios de un grupo.

Los usuarios se crean desde el menú :menuselection:`Usuarios y Grupos-->
Usuarios`, donde tendremos que rellenar la siguiente
información:

.. image:: images/directory/03-useradd.png
   :scale: 80

Nombre de usuario:
  Nombre que tendrá el usuario en el sistema, será el nombre que use para
  identificarse en los procesos de autenticación.
Nombre:
  Nombre del usuario.
Apellidos:
  Apellidos del usuario.
Comentario:
  Información adicional sobre el usuario.
Contraseña:
  Contraseña que empleará el usuario en los procesos de
  autenticación. Esta información se tendrá que dar dos veces para
  evitar introducirla incorrectamente.
Grupo:
  Es posible añadir el usuario a un grupo en el momento de su creación.

Desde :menuselection:`Usuarios y Grupos --> Usuarios` se puede obtener un
listado de los usuarios, editarlos o eliminarlos.

.. image:: images/directory/04-users.png
   :scale: 80

Mientras se edita un usuario se pueden cambiar todos los datos
anteriores exceptuando el nombre del usuario, además de la información
que tiene que ver con aquellos módulos de eBox instalados que poseen
alguna configuración específica para los usuarios. También se puede
modificar la lista de grupos a los que pertenece.

.. image:: images/directory/05-useredit.png
   :scale: 80

Editando un usuario es posible:

* Crear una cuenta para el servidor Jabber.
* Crear una cuenta para la compartición de ficheros o de PDC con una
  cuota personalizada.
* Dar permisos al usuario para usar una impresora.
* Crear una cuenta de correo electrónico para el usuario y *aliases*
  para la misma.
* Asignar permisos de acceso a las distintas aplicaciones de eGroupware.
* Asignar una extensión telefónica a dicho usuario.

En una configuración maestro-esclavo, los campos básicos de usuarios y grupos
se editan desde el maestro, mientras que el resto de atributos relacionados
con otros módulos instalados en un esclavo dado se editan desde el mismo.

.. _usercorner-ref:

Rincón del Usuario
------------------

Los datos del usuario sólo pueden ser modificados por el administrador
de eBox lo cual comienza a ser no escalable cuando el número de
usuarios que se gestiona comienza a ser grande. Tareas de
administración como cambiar la contraseña de un usuario puede hacer
perder la mayoría del tiempo del encargado de dicha labor. De ahí
surge la necesidad del nacimiento del **rincón del usuario**. Dicho
rincón es un servicio de eBox para permitir cambiar a los usuarios sus
datos. Esta funcionalidad debe ser habilitada como el resto de
módulos. El rincón del usuario se encuentra escuchando en otro puerto
por otro proceso para aumentar la seguridad del sistema.

.. image:: images/directory/06-usercorner-server.png
   :scale: 80

El usuario puede entrar en el rincón del usuario a través de:

  https://<ip_de_eBox>:<puerto_rincon_usuario>/

Una vez el usuario introduce su nombre y su contraseña puede realizar
cambios en su configuración personal. Por ahora, la funcionalidad que
se presenta es la siguiente:

* Cambiar la contraseña actual.
* Configuración del buzón de voz del usuario.
* Configurar una cuenta personal externa para recoger el correo y
  sincronizarlo con el contenido en su cuenta del servidor de correo
  en eBox.

.. image:: images/directory/07-usercorner-user.png
   :scale: 80

Ejemplo práctico A
^^^^^^^^^^^^^^^^^^

Crear un grupo en eBox llamado **contabilidad**.

.. FIXME: This is wrong with new master/slave arch

Para ello:

#. **Acción:** Activar el módulo **usuarios y grupos**. Entrar en
   :menuselection:`Estado de los módulos` y activar el módulo en caso
   de que no esté habilitado.

   Efecto:
     El módulo está activado y listo para ser usado.
     
#. **Acción:**
   Acceder a :menuselection:`Usuarios y Grupos --> Grupos`. Añadir **contabilidad** como grupo. El parámetro
   **comentario** es opcional.

   Efecto:
     El grupo **contabilidad** ha sido creado. No es necesario que se
     guarden los cambios ya que las acciones sobre LDAP tienen efecto inmediato.

Ejemplo práctico B
^^^^^^^^^^^^^^^^^^

Crear el usuario **pedro** y añadirlo al grupo **contabilidad**.

Para ello:

#. **Acción:**
   Acceder a :menuselection:`Usuarios --> Añadir usuario`. Rellenar
   los distintos campos para nuestro nuevo usuario. Se puede añadir al
   usuario **pedro** al grupo **contabilidad** desde esta pantalla.

   Efecto:
     El usuario ha sido añadido al sistema y al grupo **contabilidad**.

Comprobar desde consola que hemos añadido a nuestro usuario correctamente:

#. **Acción:**
   Ejecutar en la consola el comando::

    # id pedro

   Efecto:
    El resultado debería de ser algo como esto::

     uid=2003(pedro) gid=1901(__USERS__)
     groups=1901(__USERS__) ,2004(contabilidad)

.. include:: directory-exercises.rst
