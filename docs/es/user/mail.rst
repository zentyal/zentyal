.. _mail-service-ref:

Servicio de correo electrónico (SMTP/POP3-IMAP4)
************************************************

.. sectionauthor:: Javier Amor García <jamor@ebox-platform.com>
                   José A. Calvo <jacalvo@ebox-platform.com>
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>
                   Víctor Jímenez <vjimenez@warp.es>

El servicio de **correo electrónico** es un método de *almacenamiento y
envío* [#]_ para la composición, emisión, reserva y recepción de
mensajes sobre sistemas de comunicación electrónicos.

.. [#] **Almacenamiento y envío**: Técnica de telecomunicación en la cual la
         información se envía a una estación intermedia que almacena y después
         envía la información a su destinatario o a otra estación intermedia.

Cómo funciona el correo electrónico en Internet
===============================================

.. figure:: images/mail/mail-ab.png
   :scale: 60
   :alt: Diagrama correo electrónico Alice manda un correo a Bob

   Diagrama correo electrónico Alice manda un correo a Bob

El diagrama muestra una secuencia típica de eventos que tienen lugar cuando
Alice escribe un mensaje usando su cliente de correo o *Mail User
Agent* (MUA) con destino la dirección de correo de su destinatario.

1. Su MUA da formato al mensaje en un formato de Internet para el correo
   electrónico y usa el protocolo *Simple Mail Transfer Protocol* (SMTP) que
   envía el mensaje a su agente de envío de correos o *Mail Transfer
   Agent* (MTA).
2. El MTA mira en la dirección destino dada por el protocolo SMTP (no
   de la cabecera del mensaje), en este caso bob@b.org, y hace una
   solicitud al servicio de nombres para saber la IP del servidor de
   correo del dominio del destino (registro **MX** que vimos en el
   capítulo donde se explicaba DNS).
3. El **smtp.a.org** envía el mensaje a **mx.b.org** usando SMTP, que almacena
   el mensaje en el buzón del usuario **bob**.
4. Bob obtiene el correo a través de su MUA, que recoge el correo usando el
   protocolo *Post Office Protocolo 3* (POP3).

Esta situación puede cambiar de diversas maneras. Por ejemplo, Bob puede usar otro
protocolo de obtención de correos como es *Internet Message Access
Protocol* (IMAP) que permite leer directamente desde el servidor o usando un servicio
de **Webmail** como el que usan diversos servicios gratuitos de correo vía
*Web*.

Por tanto, podemos ver como el envío y recepción de correos entre
servidores de correo se realiza a través de SMTP pero la obtención de
correos por parte del usuario se realiza a través de POP3, IMAP o sus versiones
seguras (POP3S y IMAPS)
que permiten la interoperabilidad entre diferentes servidores y
clientes de correo. Lamentablemente, también existen protocolos
propietarios como los que usan *Microsoft Exchange* o *Lotus Notes* de
IBM.

POP3 vs. IMAP
-------------

El diseño de POP3 para recoger los mensajes del correo ayuda a las
conexiones lentas permitiendo a los usuarios recoger todo el correo de
una vez para después verlo y manipularlo sin necesidad de estar
conectado. Estos mensajes, normalmente, se borran del buzón del
usuario en el servidor, aunque actualmente la mayoría de MUAs permiten
mantenerlos.

El más moderno IMAP, permite trabajar en línea o desconectado además de sólo
borrar los mensajes depositados en el servidor de manera explícita.
Adicionalmente, permite que múltiples clientes accedan al mismo buzón o
lecturas parciales de mensajes MIME entre otras ventajas. Sin embargo, es un
protocolo bastante complicado con más carga de trabajo en el lado del servidor
que POP3, que relega dicho trabajo en el cliente. Las ventajas
principales de IMAP sobre POP3 son:

- Modo de operación conectado y desconectado.
- Varios clientes a la vez conectados al mismo buzón.
- Descarga parcial de correos.
- Información del estado del mensaje usando *banderas* (leído, borrado, respondido, ...).
- Varios buzones en el servidor (el usuario los ve en forma de
  carpetas) pudiendo hacer alguno de ellos públicos.
- Búsquedas en el lado del servidor.
- Mecanismos de extensión incluidos en el propio protocolo.

Tanto POP3 como IMAP, tienen versiones seguras, llamadas
respectivamente POP3S y IMAPS. La diferencia con la versión simple es
que usan cifrado TLS por lo que el contenido de los mensajes no puede
ser escuchado sin permiso.

Configuración de un servidor SMTP/POP3-IMAP4 con eBox
=====================================================

En el servicio de correo debemos configurar el MTA para enviar y recibir
correos así como la recepción de correos por parte de MUAs vía IMAP o POP3.

Para el envío/recepción de correos se usa Postfix [#f1]_ como servidor
SMTP. Para el servicio de recepción de correos (POP3, IMAP) se usa
Dovecot [#f2]_. Ambos con soporte para comunicación segura con
SSL.

.. rubric:: Footnotes

.. [#f1] **Postfix** *The Postfix Home Page* http://www.postfix.org .

.. [#f2] **Dovecot** *Secure IMAP and POP3 Server* http://www.dovecot.org .


Recibiendo y retransmitiendo correo
===================================

Para comprender la configuración de un sistema de correo se debe
distinguir entre recibir y retransmitir correo.

La **recepción** se realiza cuando el servidor acepta un mensaje de
correo en el que uno de los destinatarios es una cuenta perteneciente
a alguno de los dominio gestionados por el servidor. El correo puede
ser recibido de cualquier cliente que pueda conectarse al servidor.

Sin embargo, la **retransmisión** ocurre cuando el servidor de correo
recibe un mensaje de correo en el que ninguno de los destinatarios
pertenecen a ninguno de sus dominios virtuales de correo gestionados,
requiriendo por tanto su reenvío a otro servidor. La retransmisión de
correo está restringida, de otra manera los *spammers* podrían usar el
servidor para enviar *spam* en *Internet*.

eBox permite la retransmisión de correo en dos casos:

 1. usuarios autenticados
 2. una dirección de origen que pertenezca a un objeto que tenga una política de
    **retransmisión permitida**.

Configuración general
---------------------

A través de :menuselection:`Correo --> General --> Opciones del
servidor de correo --> Autenticacion` podemos gestionar las opciones
de autenticacion. Están disponibles las siguientes opciones:

:guilabel:`TLS para el servidor SMTP`: 
   Fuerza a los clientes a usar cifrado TLS, evitando la interceptación del
   contenido por personas maliciosas. 
:guilabel:`Exigir la autenticación`:
   Este parámetro activa el uso de autenticación. Un usuario debe usar
   su dirección de correo y su contraseña para identificarse, una vez
   autenticado podrá retransmitir correo a través del servidor. No se
   puede usar un alias de la cuenta de correo para autenticarse.

.. image:: images/mail/01-general.png

.. FIXME: Update the shot

En la sección :menuselection:`Correo --> General --> Opciones del
servidor de correo --> Opciones` puedes configurar los parámetros
generales del servicio de correo:

:guilabel:`Dirección del smarthost`:
  Dirección IP o nombre de dominio del *smarthost*. También se puede establecer un
  puerto añadiendo el texto `:[numero de puerto]` después de la dirección. El
  puerto por defecto, es el puerto estándar SMTP, 25.

  Si se establece esta opción eBox no enviará directamente sus
  mensajes sino que cada mensaje de correo recibido sera reenviado al
  *smarthost* sin almacenar ninguna copia. En este caso, eBox actuara
  como un intermediario entre el usuario que envía el correo y el
  servidor que enviará finalmente el mensaje.

:guilabel:`Autenticación del smarthost`:
  Determinar si el *smarthost* requiere autenticación y si es así
  proveer un usuario y contraseña.

:guilabel:`Nombre de correo del servidor`:
  Determina el nombre de correo del sistema, será usado por el
  servicio de correo como la dirección local del sistema.

:guilabel:`Dirección del postmaster`: 
  La dirección del *postmaster* por defecto es un alias del
  superusuario (`root`) pero puede establecerse a cualquier dirección,
  perteneciente a los dominios virtuales de correo gestionados o no.

  Esta cuenta está pensada para tener una manera estándar de contactar con el
  administrador de correo. Correos de notificación automáticos suelen usar
  **postmaster** como dirección de respuesta.

:guilabel:`Tamaño máximo de buzón`: 
  En esta opción se puede indica un tamaño máximo en MiB para los buzones del
  usuario. Todo el correo que exceda el limite será rechazado y el remitente
  recibirá una notificación. Esta opción puede sustituirse para cada usuario en
  la pagina :menuselection:`Usuarios y Grupos -> Usuarios`.

:guilabel:`Tamaño máximo aceptado para los mensajes`:
  Señala, si es necesario, el tamaño máximo de mensaje aceptado por el
  *smarthost* en MiB. Esta opción tendrá efecto sin importar la existencia o no
  de cualquier límite al tamaño del buzón de los usuarios.

:guilabel:`Periodo de expiración para correos borrados`:
  Si esta opción está activada el correo en la carpeta de papelera de
  los usuarios será borrado cuando su fecha sobrepase el limite de
  días establecido.

:guilabel:`Periodo de expiración para correo de spam`: 
   Esta opción se aplica de la misma manera que la opción anterior
   pero con respecto a la carpeta de *spam* de los usuarios.

Para configurar la obtención de los mensajes, hay que ir a la sección
:guilabel:`Servicios de obtención de correo`. eBox puede configurarse
como servidor de POP3 o IMAP además de sus versiones seguras POP3S y
IMAPS. En esta sección también pueden activarse los servicios para
obtener correo de direcciones externas y *ManageSieve*, estos servicios
se explicarán a partir de la sección :ref:`fetchmail-sec-ref`.

También se puede configurar eBox para que permita reenviar correo sin necesidad
de autenticarse desde determinadas direcciones de red. Para
ello, se permite una política de reenvío con objetos de red de eBox a
través de :menuselection:`Correo --> General --> Política de retransmisión para objetos de red`
basándonos en la dirección IP del cliente de correo origen. Si se
permite el reenvío de correos desde dicho objeto, cualquier miembro de
dicho objeto podrá enviar correos a través de eBox.

.. image:: images/mail/02-relay.png

.. FIXME: Update the show with the new edit in-place option

.. warning::
   Hay que tener cuidado con usar una política de *Open Relay*, es
   decir, permitir reenviar correo desde cualquier lugar, ya que con
   alta probabilidad nuestro servidor de correo se convertirá en una
   fuente de *spam*.

Finalmente, se puede configurar el servidor de correo para que use algún
filtro de contenidos para los mensajes [#]_. Para ello el servidor de
filtrado debe recibir el correo en un puerto determinado y enviar el
resultado a otro puerto donde el servidor de correo estará escuchando
la respuesta. A través de :menuselection:`Correo --> General -->
Opciones de Filtrado de Correo` se puede seleccionar un filtro de
correo personalizado o usar eBox como servidor de filtrado.

.. [#] En la sección :ref:`mailfilter-sec-ref` se amplia este tema.

.. image:: images/mail/mailfilter-options.png
   :align: center

Creación de cuentas de correo a través de dominios virtuales
------------------------------------------------------------

Para crear una cuenta de correo se debe tener un usuario creado y un
dominio virtual de correo.

Desde :menuselection:`Correo --> Dominio Virtual`, se pueden crear
tantos dominios virtuales como queramos que proveen de *nombre de
dominio* a las cuentas de correo de los usuarios de
eBox. Adicionalmente, es posible crear *alias* de un dominio virtual
de tal manera que enviar un correo al dominio virtual o a su *alias*
sea indiferente.

.. image:: images/mail/mail-vdomains.png
   :align: center

.. FIXME: Update the shot with new options

Para crear cuentas de correo lo haremos de manera análoga a la
compartición de ficheros, acudimos a :menuselection:`Usuarios y Grupos
--> Usuarios --> Crear cuenta de correo`.  Es ahí donde seleccionamos
el dominio virtual principal del usuario. Si queremos asignar al
usuario a más de una cuenta de correo lo podemos hacer a través de los
alias. Indiferentemente de si se ha usado un alias o no, el correo
sera almacenado una única vez en el buzón del usuario.  Sin embargo,
no es posible usar un alias para autenticarse, se debe usar siempre la
cuenta real.

.. image:: images/mail/03-user.png
   :align: center
   :scale: 80

Ten en cuenta que puedes decidir si deseas que a un usuario se le cree
automáticamente una cuenta de correo cuando se crea. Este comportamiento
puede ser configurado en `Usuarios y Grupos -> Plantilla de Usuario por
defecto --> Cuenta de correo`.

De la misma manera, se pueden crear *alias* para grupos. Los mensajes
recibidos por estos alias son enviados a todos los usuarios del grupo
con cuenta de correo. Los alias de grupo son creados a través de
:menuselection:`Usuarios y Grupos --> Grupos -->
Crear un alias de cuenta de correo al grupo`.  Los alias de grupo
están sólo disponibles cuando, al menos, un usuario del grupo tiene
cuenta de correo.

Finalmente, es posible definir *alias* hacia cuentas externas. El
correo enviado a un alias será retransmitido a la correspondiente
cuenta externa. Esta clase de alias se establecen por dominio virtual
de correo, no requieren la existencia de ninguna cuenta de correo y
pueden establecerse en :menuselection:`Correo --> Dominios Virtuales
--> Alias a cuentas externas`.

Gestión de cola
---------------

Desde :menuselection:`Correo --> Gestión de cola` podemos ver los correos que
todavía no han sido enviados con la información acerca del mensaje. Las
acciones que podemos realizar con estos mensajes son: eliminarlos, ver
su contenido o volver a tratar de enviarlos (*reencolarlos*). También hay dos
botones que permiten borrar o reencolar todos los mensajes en la cola.

.. image:: images/mail/04-queue.png
   :align: center

.. FIXME: Update the shot with the new buttons

.. _fetchmail-sec-ref:

Obtención de correo desde cuentas externas
----------------------------------------------

Se puede configurar eBox para recoger correo de cuentas externas y
enviarlo a los buzones de los usuarios. Para ello, deberás activar en
la sección :menuselection:`Correo --> General --> Opciones del
servidor de corre --> Servicios de obtención de correo`. Una vez
activado, los usuarios tendrán sus mensajes de correo de sus cuentas
externas recogido en el buzón de su cuenta interna. Cada usuario puede
configurar sus cuentas externas a través del rincón del usuario [#]_. El
usuario debe tener una cuenta de correo para poder hacerlo. Los
servidores externos son consultados periódicamente, así que la
obtención del correo no es instantánea.

Para configurar sus cuentas externas, un usuario debe entrar en el `Rincón del Usuario` 
y hacer clic en `Recuperar correo de cuentas externas` en el menú izquierdo. En la pagina 
se muestra la lista de cuentas de correo del usuario, el usuario puede añadir, borrar y editar
cuentas. Cada cuenta tiene los siguientes parametros:

:guilabel:`Dirección
 de correo externa`: 
   la dirección de correo externa, debe ser la dirección 
   usada para recuperar correo.
:guilabel:`Contrasena`: 
   contrasena para autenticar la cuenta externa.
:guilabel:`Servidor de correo`: 
   dirección del servidor de correo que hospeda a la cuenta externa.
:guilabel:`Protocolo`: 
   protocolo de recuperación de correo usado por la cuenta externa, puede ser uno de los   
   siguientes:  POP3, POP3S, IMAP o IMAPS.
:guilabel:`Puerto`: 
   puerto usado para conectar al servidor de correo externo.

.. image:: images/mail/usercorner-external-mail.png
   :align: center

Para obtener el correo externo, eBox usa el programa Fetchmail [#f3]_ .


.. rubric:: Footnotes

.. [#] La configuración del rincón del usuario se explica en la
       sección :ref:`usercorner-ref`.
.. [#f3] **Fetchmail** The Fetchmail Home Page http://fetchmail.berlios.de/ .

.. _sieve-sec-ref:

Lenguaje Sieve y protocolo ManageSieve
--------------------------------------

El **lenguaje Sieve** [#f4]_ permite el control al usuario de cómo su
correo es recibido, permitiendo, entre otras cosas, clasificarlo en
carpetas IMAP, reenviarlo o el uso de un mensaje por ausencia
prolongada (o vacaciones).

**ManageSieve** es un protocolo de red que permite a los usuarios gestionar sus
*scripts* Sieve. Para usarlo, es necesario que el cliente de correo pueda entender
dicho protocolo [#f5]_ .

Para usar *ManageSieve* en eBox, debes activar el servicio en
:menuselection:`Correo--> General --> Opciones de servidor de correo -> Servicios
de obtención de correo`  y podrá ser usado por todos los usuarios con cuenta de
correo. Si *ManageSieve* está activado y el módulo de **correo web** [#f6]_ en
uso, el interfaz de gestión para *scripts* Sieve estará disponible en el correo web.

La autenticación en *ManageSieve* se hace con la cuenta de correo del
usuario y su contraseña.

Los *scripts* de Sieve de una cuenta son ejecutados independientemente de si
*ManageSieve* está activado o no.

.. rubric:: Footnotes

.. [#f4] Para mas información sobre Sieve http://sieve.info/ .
.. [#f5] Para tener una lista de clientes Sieve http://sieve.info/clients .
.. [#f6] El módulo de **correo web** (*webmail*) se explica en el
         capítulo :ref:`webmail-ref`.

Configuración del cliente de correo
-----------------------------------

A no ser que los usuarios sólo usen el correo a través del módulo de
de **correo web** o a través de la aplicación de correo de
**groupware**, deberán configurar su cliente de correo para usar el
servidor de correo de eBox. El valor de los parámetros necesarios
dependerán de la configuración del servicio de correo.

Hay que tener en cuenta que diferentes clientes de correo podrán usar distintos
nombres para estos parámetros, por lo que debido a la multitud de clientes
existente esta sección es meramente orientativa.

Parámetros SMTP
===============

Servidor SMTP:
   Introducir la dirección del servidor eBox. La dirección puede ser
   descrita como una dirección IP o como nombre de dominio.

Puerto SMTP:
   25, si usas TLS puedes usar en su lugar el puerto 465.

Conexión segura:
   Seleccionar `TLS` si tienes activada la opción :guilabel:`TLS para
   el servidor SMTP`, en otro caso seleccionar `ninguna`. Si se usa
   TLS lee la advertencia aparece más adelante sobre TLS/SSL.

Usuario SMTP:
   Como nombre de usuario se debe usar la dirección de correo
   completa del usuario, no uses su nombre de usuario o alguno de sus alias de
   correo. Esta opción sólo es obligatoria si está habilitado el
   parámetro :guilabel:`Exigir autenticación`.

Contraseña SMTP:
   La contraseña del usuario.

Parámetros POP3
===============

Sólo puedes usar configuración POP3 cuando el servicio POP3 o POP3S
está activado en eBox.

Servidor POP3:
   Introducir la dirección de eBox de la misma manera que la sección
   de parámetros SMTP.

Puerto POP3:
   110 o 995 en el caso de usar POP3S.

Conexión segura:
   Selecciona `SSL` en caso de que se use POP3S, `ninguno` si
   se usa POP3. Si se utiliza POP3S, ten en cuenta la advertencia que
   aparece más adelante sobre TLS/SSL.

Usuario POP3:
   Dirección de correo completa del usuario, no se debe usar ni el
   nombre de usuario ni ninguno de sus alias de correo.

Contraseña POP3:
   La contraseña del usuario.

Parámetros IMAP
===============

Sólo se puede usar la configuración IMAP si el servicio IMAP o IMAPS
está activo.

Servidor IMAP:
   Introducir la dirección de eBox de la misma manera que la sección
   de parámetros SMTP.

Puerto IMAP:
   443 o 993 en el caso de usar IMAPS.

Conexión segura:
   Seleccionar `SSL` en caso de que se use IMAPS, `ninguno` si
   se utiliza IMAP. Si se usa IMAPS, leer la advertencia que aparece
   más adelante sobre TLS/SSL.

Usuario IMAP:
   Dirección de correo completa del usuario, no se debe usar ni el
   nombre de usuario ni ninguno de sus alias de correo.

Contraseña IMAP:
   La contraseña del usuario.

.. warning::

   En las implementaciones de los clientes de correo a veces hay
   confusión sobre el uso de los protocolos SSL y TLS. Algunos
   clientes usan `SSL` para indicar que van a conectar con `TLS`,
   otros usan `TLS` para indicar que van a tratar de conectar al
   servicio a través de un puerto tradicionalmente usado por las
   versiones del protocolo en claro. De hecho, en algunos clientes
   hará falta probar tanto los modos `SSL` como `TLS` para averiguar
   cual de los métodos funciona correctamente.

   Tienes mas información sobre este asunto en el *wiki* de Dovecot,
   http://wiki.dovecot.org/SSL .

Parámetros para ManageSieve
===========================

Para conectar a *ManageSieve*, se necesitan los siguientes parámetros:

Servidor Sieve:
   El mismo que tu servidor IMAP o POP3.

Puerto:
   4190, hay que tener en cuenta que algunas aplicaciones usan, por error
   el puerto número 2000 como puerto por defecto para ManageSieve.

Conexión segura:
   Activar esta opción.

Nombre de usuario:
   Dirección de correo completa, como anteriormente evitar el nombre
   de usuario o cualquiera de sus alias de correo.

Contraseña:
   Contraseña del usuario. Algunos clientes permiten indicar que se
   va a usar la misma autenticación que para IMAP o POP, si esto es posible,
   hay que seleccionar dicha opción. 

Cuenta para recoger todo el correo
------------------------------------

Una **cuenta para recoger todo el correo** es una cuenta que recibe
una copia de todo el correo enviado y recibido por un dominio de
correo. En eBox se permite definir una de estas cuentas por cada
dominio; para establecerla se debe ir a la pagina
:menuselection:`Correo --> Dominios Virtuales` y después hacer clic
en la celda :guilabel:`Opciones`.

Todos los mensajes enviados y recibidos por el dominio serán enviados
como copia oculta (CCO ó BCC) a la dirección definida. Si la dirección
rebota el correo, será devuelto al remitente.

.. _mail-conf-exercise-ref:

Ejemplo práctico
^^^^^^^^^^^^^^^^
Crear un dominio virtual para el correo. Crear una cuenta de usuario y una
cuenta de correo en el dominio creado para dicho usuario. Configurar la
retransmisión para el envío de correo. Enviar un correo de prueba con la cuenta
creada a una cuenta externa.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activa el módulo **Correo**, para ello marca su casilla en la
   columna :guilabel:`Estado`. Habilitar primero los módulos **Red** y
   **Usuarios y grupos** si no se encuentran habilitados con anterioridad.

   Efecto:
     eBox solicita permiso para sobreescribir algunos ficheros.

#. **Acción:**
   Leer los cambios de cada uno de los ficheros que van a ser modificados y
   otorgar permiso a eBox para sobreescribirlos.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Acceder al menú :menuselection:`Correo --> Dominio Virtual`, pulsar
   :guilabel:`Añadir nuevo`, introducir un nombre para el dominio y
   pulsar el botón :guilabel:`Añadir`.

   Efecto:
     eBox nos notifica de que debemos salvar los cambios para usar el
     dominio.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     Ahora ya podemos usar el dominio de correo que hemos añadido.

#. **Acción:**
   Acceder a :menuselection:`Usuarios y Grupos --> Usuarios --> Añadir usuario`,
   rellenar sus datos y pulsar el botón :guilabel:`Crear`.

   Efecto:
     El usuario se añade inmediatamente sin necesidad de salvar cambios.
     Aparece la pantalla de edición del usuario recién creado.

#. **Acción:**
    (Este paso sólo es necesario si has deshabilitado la opción de crear
    cuentas de correo automáticamente en `Usuarios y Grupos --> Plantilla de
    Usuario por defecto --> Cuenta de correo`). Escribir un nombre para la
    cuenta de correo del usuario en la sección :guilabel:`Crear cuenta de
    correo` y pulsar el botón :guilabel:`Crear`.

   Efecto:
     La cuenta se ha añadido inmediatamente y nos aparecen opciones para
     eliminarla o crear *alias* para ella.

#. **Acción:**
   Acceder al menú :menuselection:`Objetos --> Añadir nuevo`. Escribir
   un nombre para el objeto y pulsar :guilabel:`Añadir`.  Pulsar el
   icono de :guilabel:`Miembros` del objeto creado. Escribir de nuevo
   un nombre para el miembro, introducir la dirección IP de la máquina
   desde donde se enviará el correo y pulsar :guilabel:`Añadir`.

   Efecto:
     El objeto se ha añadido temporalmente y podemos usarlo en otras partes
     de la interfaz de eBox, pero no será persistente hasta que se guarden
     cambios.

#. **Acción:**
   Acceder a :menuselection:`Correo --> General --> Política de
   reenvío sobre objetos`. Seleccionar el objeto creado en el paso
   anterior asegurándose de que está marcada la casilla
   :guilabel:`Permitir reenvío` y pulsar el botón :guilabel:`Añadir`.

   Efecto:
     El botón :guilabel:`Guardar Cambios` estará activado.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     Se ha añadido una política de reenvío para el objeto que hemos creado,
     que permitirá el envío de correos al exterior para ese origen.

#. **Acción:**
   Configurar el cliente de correo seleccionado para que use eBox
   como servidor SMTP y enviar un correo de prueba desde la cuenta que hemos
   creado a una cuenta externa.

   Efecto:
     Transcurrido un breve periodo de tiempo deberíamos recibir el correo
     enviado en el buzón de la cuenta externa.

#. **Acción:**
   Comprobar en el servidor de correo a través del fichero de registro
   `/var/log/mail.log` como el correo se ha enviado correctamente.

.. include:: mail-exercises.rst
