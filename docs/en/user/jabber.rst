Servicio de mensajería instantánea (Jabber/XMPP)
************************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Víctor Jiménez <vjimenez@warp.es>

Las aplicaciones de **mensajería instantánea** permiten gestionar una lista de
personas con las que uno desea mantenerse en contacto intercambiando mensajes.
Convierte la comunicación asíncrona proporcionada por el correo electrónico
en una comunicación síncrona en la que los participantes pueden comunicarse
en tiempo real.

Además de la conversación básica permite otras prestaciones como:

* Salas de conversación.
* Transferencia de ficheros.
* Pizarra compartida que permite ver dibujos realizados por un
  interlocutor.
* Conexión simultánea desde distintos dispositivos con prioridades
  (desde el móvil y el ordenador dando preferencia a uno de ellos para la
  recepción de mensajes).

En la actualidad existen multitud de protocolos de mensajería instantánea como
ICQ, AIM o Yahoo! Messenger cuyo funcionamiento es básicamente centralizado y
propietario.

Sin embargo, también existe Jabber/XMPP que es un conjunto de
protocolos y tecnologías que permiten el desarrollo de sistemas de
mensajería distribuidos. Este protocolo es público, abierto,
flexible, extensible, distribuido y seguro, y aunque todavía sigue en
proceso de estandarización ha sido adoptado por Cisco o Google, para su
servicio de mensajería Google Talk, entre otros.

eBox usa Jabber/XMPP como protocolo de mensajería instantánea. Se encuentra
integrado con los usuarios eBox a través de :guilabel:`Servicio
Jabber`. eBox usa como herramienta **jabberd2** [#]_, servidor XMPP
escrito en C.

.. [#] **jabberd 2.x** - *XMPP server* http://jabberd2.xiaoka.com/

Configuración un servidor Jabber/XMPP con eBox
----------------------------------------------

En primer lugar, debemos habilitar el módulo. Para ello iremos a la
sección :guilabel:`Estado del módulo` del menú de eBox y
seleccionaremos la casilla :guilabel:`jabber`.  Si no tenemos
habilitado el módulo :guilabel:`usuarios y grupos` deberá ser
habilitado previamente ya que depende de él.

.. figure:: images/jabber/jabber.png
   :scale: 80

   Configuración general del servicio Jabber

A la configuración general del servidor se accede a través del menú
:menuselection:`Servicio Jabber`, una vez allí sólo necesitamos configurar
los siguientes parámetros:

Nombre de dominio:
  Especifica el nombre del servidor, esto hará que las cuentas de los usuarios
  sean de la forma *usuario@dominio*, siendo *dominio* cualquier nombre de
  dominio que determinemos.

  .. tip:: *dominio* debería tener un registro DNS donde el servidor
           Jabber estuviera aceptando conexiones. Por ejemplo, si eBox tiene el
           nombre *intserver.company.com*, el dominio Jabber debería ser
           *intserver.company.com*.

Conectar a otros servidores:
  Debemos marcar esta casilla si queremos que nuestros usuarios puedan contactar
  con usuarios de otros servidores externos. Si por el contrario queremos un
  servidor privado, sólo para nuestra red interna, deberá dejarse desmarcada.

Habilitar MUC (*Multi User Chat*):
  Habilita las salas de conferencia [#]_ para que existan salas donde haya
  más de dos usuarios conectados. Dando la posibilidad a invitaciones,
  moderación y administración de la sala, tipos de salas
  especializadas, entrada con contraseña, etc. Dichas salas
  pueden ser permanentes o creadas de manera momentánea en el servidor.

Soporte SSL:
  Especifica si las comunicaciones con el servidor serán cifradas. Podemos
  desactivarlo, hacer que sea obligatorio o dejarlo como opcional. Si lo
  dejamos como opcional será en la configuración del cliente donde se
  especifique si se quiere usar SSL.

.. [#] Existe un estándar definido para las salas de conferencia de
       Jabber/XMPP en http://xmpp.org/extensions/xep-0045.html

Para registrar usuarios en el servicio Jabber/XMPP lo haremos directamente
desde la página de edición de las propiedades del usuario. Simplemente
tenemos que ir al menú :menuselection:`Usuarios --> Añadir usuario` de
eBox si queremos crear un nuevo usuario con cuenta en el servidor
Jabber, o :menuselection:`Editar usuario` si queremos habilitar la cuenta
Jabber para alguno de los usuarios existentes.

.. figure:: images/jabber/user-jabber.png
   :scale: 80

   Configuración de cuenta Jabber de un usuario

Como se puede ver en la imagen, nos aparecerá una sección llamada
**Cuenta Jabber** donde podemos seleccionar si la cuenta está activada
o desactivada. Además, podemos especificar si el usuario en cuestión
tendrá privilegios de administrador en el servidor Jabber marcando la
casilla correspondiente. Los privilegios de administrador permiten
ver los usuarios conectados al servidor, enviarles mensajes,
configurar el mensaje mostrado al conectarse (MOTD, *Message Of The
Day*) y enviar un anuncio a todos los usuarios conectados
(*broadcast*).

Configuración de un cliente Jabber
----------------------------------

Para el ejemplo de configuración de un cliente Jabber vamos a usar **Pidgin**,
aunque en caso de utilizar otro cliente distinto los pasos a seguir serían
muy similares.

**Pidgin** [#]_ es un cliente multiprotocolo que permite gestionar varias cuentas a
la vez. Además de Jabber/XMPP soporta muchos otros protocolos como IRC,
MSN, Yahoo!, etc.

.. [#] Pidgin, the universal chat client http://www.pidgin.im/.

Pidgin viene incluido por defecto en la versión de escritorio de
Ubuntu y podemos encontrarlo en el menú :menuselection:`Internet -->
Cliente de mensajería Internet Pidgin`. Al arrancar Pidgin, si no
tenemos ninguna cuenta creada, nos aparecerá la ventana de gestión de
cuentas tal como aparece en la imagen.

.. image:: images/jabber/pidgin-01-cuentas.png
   :scale: 60
   :align: center

Desde esta ventana podemos tanto añadir cuentas, como modificar y borrar las
cuentas existentes.

Pulsando el botón :guilabel:`Añadir` aparecerá la ventana de
configuración de la cuenta, que se divide en dos pestañas de
configuración básica y avanzada.

Para la configuración básica de nuestra cuenta Jabber/XMPP, deberemos
seleccionar en primer lugar el protocolo :guilabel:`XMPP`. El nombre
de usuario y contraseña deberán coincidir con los datos de cualquiera
de los usuarios a los que se les haya habilitado la cuenta Jabber
desde la interfaz de eBox. El dominio deberá ser el mismo que hayamos
seleccionado en la configuración del :guilabel:`Servicio Jabber` en
eBox. En el campo :guilabel:`Apodo local` introduciremos el nombre que queramos
mostrar a nuestros contactos.

.. image:: images/jabber/pidgin-02-conf-basica.png
   :scale: 60
   :align: center

En caso de que el dominio del servidor Jabber no sea a su vez un
dominio del DNS de eBox, tendremos que especificar la IP o nombre de
dominio de la máquina eBox. Esto lo haremos en la pestaña
:menuselection:`Avanzadas` en el campo :guilabel:`Conectar con el
servidor`.

.. image:: images/jabber/pidgin-03-conf-avanzada.png
   :scale: 60
   :align: center

Si además tenemos configurado el servicio Jabber para que requiera
SSL, debemos marcar las casillas :guilabel:`Requiere SSL/TLS` y
:guilabel:`Forzar SSL antiguo`, así como cambiar el :guilabel:`Puerto
de conexión` al 5223.

.. _jabber-exercise-ref:

Ejemplo práctico
^^^^^^^^^^^^^^^^
Activar el servicio Jabber y asignarle un nombre de dominio que eBox sea
capaz de resolver.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activar el módulo :guilabel:`jabber`, para ello marca su casilla en la
   columna :guilabel:`Estado`. Nos informa de los cambios que va a realizar
   en el sistema. Permitir la operación pulsando el botón
   :guilabel:`Aceptar`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Añadir un dominio, con el nombre que hayamos elegido y cuya dirección IP
   sea la de la máquina eBox, de la misma forma que se hizo en
   :ref:`dns-exercise-ref`.

   Efecto:
     Podremos usar el dominio añadido como dominio para nuestro Servicio
     Jabber.

#. **Acción:**
   Acceder al menú :menuselection:`Servicio Jabber`. En el campo
   :guilabel:`Nombre de dominio` escribir el nombre del dominio que acabamos
   de añadir. Pulsar el botón :guilabel:`Aplicar cambios`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     El servicio Jabber ha quedado listo para ser usado.

.. include:: jabber-exercises.rst
