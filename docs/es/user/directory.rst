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

Se puede crear un grupo desde el menú :menuselection:`Usuarios y Grupos -->
Grupos`. Un grupo se identifica por su nombre, y puede contener
una descripción.

.. image:: images/directory/01-groupadd.png

A través de :menuselection:`Usarios y Grupos --> Grupos` se pueden ver
todos los grupos existentes para poder editarlos o borrarlos.

Mientras se edita un grupo, se pueden elegir los usuarios que pertenecen al
grupo, además de la información que tiene que ver con aquellos módulos de eBox
instalados que poseen alguna configuración específica para los grupos de
usuarios.

.. image:: images/directory/02-groupedit.png

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
  Contraseña que empleará el usuario en los procesos de autenticación.
Grupo:
  Es posible añadir el usuario a un grupo en el momento de su creación.

Desde :menuselection:`Usuarios y Groups --> Usuarios --> Editar Usuario` se puede obtener un
listado de los usuarios, editarlos o eliminarlos.

.. image:: images/directory/04-users.png

Mientras se edita un usuario se pueden cambiar todos los datos
anteriores exceptuando el nombre del usuario, además de la información
que tiene que ver con aquellos módulos de eBox instalados que poseen
alguna configuración específica para los usuarios. También se puede
modificar la lista de grupos a los que pertenece.

.. image:: images/directory/05-useredit.png

Editando un usuario es posible:

* Crear una cuenta para el servidor Jabber.
* Crear una cuenta para la compartición de ficheros o de PDC con una
  cuota personalizada.
* Dar permisos al usuario para usar una impresora.
* Crear una cuenta de correo electrónico para el usuario y *aliases*
  para la misma.
* Asignar permisos de acceso a las distintas aplicaciones de eGroupware.
* Habilitar y asignar una extensión telefónica a dicho usuario.

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
   :scale: 50

El usuario puede entrar en el rincón del usuario a través de:

  https://<ip_de_eBox>:<puerto_rincon_usuario>/

Una vez el usuario introduce su nombre y su contraseña puede realizar
cambios en su configuración personal. Por ahora, la funcionalidad que
se presenta es la siguiente:

* Cambiar la contraseña actual.
* Configuración del buzón de voz del usuario.

.. image:: images/directory/07-usercorner-user.png
   :scale: 50


Ejemplo práctico A
^^^^^^^^^^^^^^^^^^

Crear un grupo en eBox llamado **contabilidad**.

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
