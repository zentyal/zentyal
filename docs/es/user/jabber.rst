Servicio de mensajería instantánea (Jabber/XMPP)
************************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Jorge Salamero Sanz <jsalamero@ebox-platform.com>,
                   Víctor Jiménez <vjimenez@warp.es>

Las aplicaciones de **mensajería instantánea** permiten gestionar una lista de
personas con las que uno desea mantenerse en contacto intercambiando mensajes.
Convierte la comunicación asíncrona proporcionada por el correo electrónico
en una comunicación síncrona en la que los participantes pueden comunicarse
en tiempo real.

Además de la conversación básica permite otras prestaciones como:

* Salas de conversación.
* Transferencia de ficheros.
* Actualizaciones de estado (por ejemplo: ocupado, al teléfono, ausente).
* Pizarra compartida que permite ver y mostrar dibujos a los contactos.
* Conexión simultánea desde distintos dispositivos con prioridades
  (por ejemplo: desde el móvil y el ordenador dando preferencia a uno de
  ellos para la recepción de mensajes).

En la actualidad existen multitud de protocolos de mensajería instantánea como
ICQ, AIM, MSN o Yahoo! Messenger cuyo funcionamiento es básicamente centralizado y
propietario.

Sin embargo, también existe Jabber/XMPP que es un conjunto de
protocolos y tecnologías que permiten el desarrollo de sistemas de
mensajería distribuidos. Estos protocolos son públicos, abiertos,
flexibles, extensibles, distribuidos y seguros. Aunque todavía sigue en
proceso de estandarización, ha sido adoptado por Cisco o Google (para su
servicio de mensajería Google Talk) entre otros.

eBox usa Jabber/XMPP como protocolo de mensajería instantánea, integrando los
usuarios con las cuentas de Jabber. El servidor XMPP **jabberd2** [#]_ es el
elegido para el servicio de Jabber/XMPP en eBox.

.. [#] **jabberd2** - *servidor XMPP* <http://jabberd2.xiaoka.com/>.

Configuración de un servidor Jabber/XMPP con eBox
-------------------------------------------------

Para configurar el servidor Jabber/XMPP en eBox, primero debemos comprobar
en :guilabel:`Estado del Módulo` si el módulo :guilabel:`Usuarios y Grupos`
está habilitado, ya que Jabber depende de él. Entonces marcaremos la casilla
:guilabel:`Jabber` para habilitar el módulo de eBox de Jabber/XMPP.

.. figure:: images/jabber/jabber.png
   :scale: 80

   Configuración general del servicio Jabber

Para configurar el servicio, accederemos a :menuselection:`Jabber` en el menú
izquierdo, definiendo los siguientes parámetros:

:guilabel:`Nombre de dominio`:
  Especifica el nombre de dominio del servidor. Esto hará que las cuentas de
  los usuarios sean de la forma *usuario@dominio*.

  .. tip:: *dominio* debería estar registrado en el servidor DNS para que pueda
           resolverse desde los clientes.

:guilabel:`Conectar a otros servidores`:
  Para que nuestros usuarios puedan contactar con usuarios de otros servidores
  externos. Si por el contrario queremos un servidor privado, sólo para nuestra
  red interna, deberá dejarse desmarcada.

:guilabel:`Habilitar MUC (Multi User Chat)`:
  Habilita las salas de conferencias (conversaciones para más de dos usuarios).

  .. tip:: las salas de conferencias residen bajo el dominio *conference.dominio*
           que como el :guilabel:`Nombre de dominio` debería estar registrado en
           el servidor DNS para que pueda resolverse desde los clientes también.

:guilabel:`Soporte SSL`:
  Especifica si las comunicaciones (autentificación y mensajes) con el servidor
  serán cifradas o en texto plano. Podemos desactivarlo, hacer que sea obligatorio
  o dejarlo como opcional. Si lo dejamos como opcional será en la configuración
  del cliente Jabber donde se especifique si se quiere usar SSL.

Para crear cuentas de usuario de Jabber/XMPP iremos a
:menuselection:`Usuarios --> Añadir usuario` si queremos crear una nueva
cuenta o a :menuselection:`Usuarios --> Editar usuario` si solamente
queremos habilitar la cuenta de Jabber para un usuario ya existente.

.. figure:: images/jabber/jabber-account.png
   :scale: 80

   Configuración de cuenta Jabber de un usuario

Como se puede ver, aparecerá una sección llamada **Cuenta Jabber** donde
podemos seleccionar si la cuenta está activada o desactivada. Además, podemos
especificar si el usuario en cuestión tendrá privilegios de administrador.
Los privilegios de administrador permiten ver los usuarios conectados al servidor,
enviarles mensajes, configurar el mensaje mostrado al conectarse (MOTD, *Message Of The
Day*) y enviar un anuncio a todos los usuarios conectados (*broadcast*).

Configuración de un cliente Jabber
----------------------------------

Para ilustrar la configuración de un cliente Jabber, vamos a usar **Pidgin**
y **Psi**, aunque en caso de utilizar otro cliente distinto, los pasos a seguir
serían muy similares.

Pidgin
^^^^^^

**Pidgin** [#]_ es un cliente multiprotocolo que permite gestionar varias
cuentas a la vez. Además de Jabber/XMPP, Pidgin soporta muchos otros protocolos
como IRC, ICQ, AIM, MSN y Yahoo!.

.. [#] **Pidgin**, *the universal chat client* <http://www.pidgin.im/>.

Pidgin era el cliente por omisión del escritorio Ubuntu hasta la versión *Karmic*,
pero todavía sigue siendo el cliente de mensajería más popular. Lo podemos encontrar
en :menuselection:`Internet --> Cliente de mensajería Internet Pidgin`. Al arrancar
Pidgin, si no tenemos ninguna cuenta configurada, nos aparecerá la ventana de
gestión de cuentas tal como aparece en la imagen.

.. image:: images/jabber/pidgin1.png
   :scale: 60
   :align: center

Desde esta ventana podemos tanto añadir cuentas, como modificar y borrar las
cuentas existentes.

Pulsando el botón :guilabel:`Añadir`, aparecerán dos pestañas de
configuración básica y avanzada.

Para la configuración :guilabel:`Básica` de la cuenta Jabber, deberemos
seleccionar en primer lugar el protocolo :guilabel:`XMPP`. El :guilabel:`Nombre
de usuario` y :guilabel:`Contraseña` deberán ser los mismos que la cuenta Jabber
tiene en eBox. El dominio deberá ser el mismo que hayamos definido en la
configuración del módulo de Jabber/XMPP de eBox. Opcionalmente, en el campo
:guilabel:`Apodo local` introduciremos el nombre que queramos mostrar a nuestros
contactos.

.. image:: images/jabber/pidgin2.png
   :scale: 60
   :align: center

En la pestaña :guilabel:`Avanzada` está la configuración de SSL/TLS.
Por defecto :guilabel:`Requerir SSL/TLS` está marcado, así que si hemos
deshabilitado :guilabel:`Soporte SSL` debemos desmarcar esto y marcar
:guilabel:`Permitir autentificación en texto plano sobre hilos no cifrados`.

.. image:: images/jabber/pidgin3.png
   :scale: 60
   :align: center

Si no cambiamos el certificado SSL por defecto, aparecerá un aviso preguntando
si queremos aceptarlo o no.

.. image:: images/jabber/pidgin4.png
   :scale: 60
   :align: center

Psi
^^^

**Psi** [#]_ es un cliente de Jabber/XMPP que permite manejar múltiples
cuentas a la vez. Rápido y ligero, Psi es código abierto y compatible
con Windows, Linux y Mac OS X.

.. [#] **Psi**, *The Cross-Platform Jabber/XMPP Client For Power Users* <http://psi-im.org/>.

Al arrancar Psi, si no tenemos ninguna cuenta configurada todavía, aparecerá
una ventana preguntando si queremos usar una cuenta ya existente o registrar
una nueva, como aparece en la imagen. Seleccionaremos :guilabel:`Usar una cuenta
existente`.

.. image:: images/jabber/psi1.png
   :scale: 60
   :align: center

En la pestaña :guilabel:`Cuenta` definiremos la configuración básica como el
:guilabel:`Jabber ID` o JID que es *usuario@dominio* y la :guilabel:`Contraseña`.
Este usuario y contraseña deberán ser los mismos que la cuenta Jabber tiene en eBox.
El dominio deberá ser el mismo que hayamos definido en la configuración del módulo
de Jabber/XMPP de eBox.

.. image:: images/jabber/psi2.png
   :scale: 60
   :align: center

En la pestaña :guilabel:`Conexión` podemos encontrar la configuración de SSL/TLS
entre otras. Por omisión, :guilabel:`Cifrar conexión: Cuando esté disponible` está
marcado. Si deshabilitamos en eBox el :guilabel:`Soporte SSL` debemos cambiar
:guilabel:`Permitir autentificación en claro` a :guilabel:`Siempre`.

.. image:: images/jabber/psi3.png
   :scale: 60
   :align: center

Si no hemos cambiado el certificado SSL aparecerá un aviso preguntando si queremos
aceptarlo o no. Para evitar este aviso marcaremos :guilabel:`Ignorar avisos SSL` en
la pestaña :guilabel:`Conexión` que vimos en el anterior paso.

.. image:: images/jabber/psi4.png
   :scale: 60
   :align: center

La primera vez que conectemos, el cliente mostrará un error inofensivo porque
todavía no hemos publicado nuestra información personal en el servidor.

.. image:: images/jabber/psi5.png
   :scale: 60
   :align: center

Opcionalmente, podremos publicar información sobre nosotros aquí.

.. image:: images/jabber/psi6.png
   :scale: 60
   :align: center

Una vez publicada, este error no aparecerá de nuevo.

.. image:: images/jabber/psi7.png
   :scale: 60
   :align: center

.. _jabber-exercise-ref:

Configurando salas de conferencia Jabber
----------------------------------------

El servicio Jabber MUC (*Multi User Chat*) permite a varios usuarios intercambiar
mensajes en el contexto de una sala. Funcionalidades como asuntos, invitaciones,
posibilidad de expulsar y prohibir la entrada a usuarios, requerir contraseña y
muchas más están disponibles en las salas de Jabber. Para una especificación
completa, comprueba el borrador XEP-0045 [#]_.

.. [#] La especificación de las salas de conversación Jabber/XMPP está disponible en <http://xmpp.org/extensions/xep-0045.html>.

Una vez que hayamos habilitado :guilabel:`Habilitar MUC (Multi User Chat)`: en
la sección :menuselection:`Jabber` del menú de eBox, el resto de la configuración
se realiza desde los clientes Jabber.

Todo el mundo puede crear una sala en el servidor Jabber/XMPP de eBox y el usuario
que la crea se convierte en el administrador para esa sala. Este administrador
puede definir todos los parámetros de configuración, añadir otros usuarios
como moderadores o administradores y destruir la sala.

Uno de los parámetros que deberíamos destacar es :guilabel:`Hacer Sala
Persistente`.  Por omisión, todas las salas se destruyen al poco
después de que su último participante salga. Estas son llamadas salas
dinámicas y es el método preferido para conversaciones de varios
usuarios. Por otra parte, las salas persistentes deben ser destruidas
por uno de sus administradores y se utilizan habitualmente para grupos
de trabajo o asuntos.

En Pidgin para entrar en una sala hay que ir a :guilabel:`Contactos --> Entrar en una Sala...`.
Aparecerá una ventana de :guilabel:`Entrar en una Sala` preguntando alguna información
como el :guilabel:`Nombre de la sala`, el :guilabel:`Servidor` que debería ser
*conference.dominio*, el :guilabel:`Usuario` y la :guilabel:`Contraseña` en caso de ser
necesaria.

.. image:: images/jabber/pidgin5.png
   :scale: 60
   :align: center

El primer usuario en entrar a una nueva sala la bloqueará y se le preguntará si
quiere :guilabel:`Configurar la Sala` o :guilabel:`Aceptar la Configuración por Omisión`.

.. image:: images/jabber/pidgin6.png
   :scale: 60
   :align: center

En :guilabel:`Configuración de la Sala` podremos configurar todos los parámetros de la sala.
Esta ventana de configuración puede ser abierta posteriormente ejecutando */config* en la
ventana de conversación.

.. image:: images/jabber/pidgin7.png
   :scale: 60
   :align: center

Una vez configurada, otros usuarios podrán entrar en la sala bajo la configuración aplicada
estando la sala lista para su uso.

.. image:: images/jabber/pidgin8.png
   :scale: 60
   :align: center

En Psi para entrar en una sala deberemos ir a :guilabel:`General --> Entrar en una Sala`.
Una ventana de :guilabel:`Entrar en una Sala` aparecerá preguntando alguna información
como el :guilabel:`Servidor` que deberá ser *conference.dominio*, el :guilabel:`Nombre de la Sala`,
el :guilabel:`Nombre de Usuario` y la :guilabel:`Contraseña` en caso de ser necesaria.

.. image:: images/jabber/psi8.png
   :scale: 60
   :align: center

El primer usuario en entrar a una nueva sala la bloqueará y se le pedirá que la configure.
En la esquina superior derecha hay un botón que despliega un menú contextual dónde aparece
la opción :guilabel:`Configurar Sala`.

.. image:: images/jabber/psi9.png
   :scale: 60
   :align: center

En :guilabel:`Configuración de la Sala` podremos configurar todos los parámetros de la sala.

.. image:: images/jabber/psi10.png
   :scale: 60
   :align: center

Una vez configurada, otros usuarios podrán entrar en la sala bajo la configuración aplicada
estando la sala lista para su uso.

Ejemplo práctico
----------------

Activar el servicio Jabber/XMPP y asignarle un nombre de dominio que eBox y
los clientes sean capaces de resolver.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del Módulo` y
   activar el módulo :guilabel:`Jabber`. Cuando nos informe de los cambios
   que va a realizar en el sistema, permitir la operación pulsando el botón
   :guilabel:`Aceptar`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Añadir un dominio con el nombre que hayamos elegido y cuya dirección IP
   sea la de la máquina eBox, de la misma forma que se hizo en
   :ref:`dns-exercise-ref`.

   Efecto:
     Podremos usar el dominio añadido como dominio para nuestro servicio
     Jabber/XMPP.

#. **Acción:**
   Acceder al menú :menuselection:`Jabber`. En el campo
   :guilabel:`Nombre de dominio`, escribir el nombre del dominio que acabamos
   de añadir. Pulsar el botón :guilabel:`Aplicar Cambios`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     El servicio Jabber/XMPP ha quedado listo para ser usado.

.. include:: jabber-exercises.rst
