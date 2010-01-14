.. _mail-service-ref:

Servicio de correo electrónico (SMTP/POP3-IMAP4)
************************************************

.. sectionauthor:: Jose A. Calvo <jacalvo@ebox-platform.com>
                   Enrique J. Hernandez <ejhernandez@ebox-platform.com>
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

POP3 y IMAP
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

Tanto POP3 como IMAP, tienen versiones seguras, llamadas respectivamente POP3S y
IMAPS. La diferencia con la versión normal es que usan cifrado TLS por lo
que el contenido de los mensajes no puede ser espiado.


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

Configuración general
---------------------

A través de :menuselection:`Correo --> General --> Opciones` podemos acceder
a la configuración general del correo para :guilabel:`exigir la autenticación`,
para enviar correos a través del servidor o permitir el cifrado de la comunicación
SMTP con la opción :guilabel:`TLS para el servidor SMTP`.

.. image:: images/mail/01-general.png

Además se puede dar servicio de *relay*, esto es, reenviar correos
cuyo origen y destino es diferente a cualquiera de los dominios
gestionados por el servidor.

También en :menuselection:`Correo --> General --> Opciones` podemos
configurar eBox para que en vez de enviar directamente el correo, sea
un *smarthost* el que lo haga. Así cada mensaje de correo que le
llegue a eBox, será reenviado sin almacenarlo al *smarthost*
configurado para ello. En ese caso, eBox sería un intermediario entre
el usuario que envía el correo y el servidor que realmente lo
envía. Se configuran los siguientes parámetros:

:guilabel:`Dirección del smarthost`:
  Dirección IP o nombre de dominio del smarthost. También se puede establecer un
  puerto añadiendo el texto `:[numero de puerto]` después de la dirección. El
  puerto por defecto, es el puerto estandard SMTP, 25.
:guilabel:`Autenticación del smarthost`:
  Determinar si el *smarthost* requiere autenticación y si es así
  proveer un usuario y contraseña.
:guilabel:`Nombre de correo del servidor`:
  Determina el nombre de correo del sistema, sera usado por el servicio de como
  la dirección local del sistema.
:guilabel:`Remite para el correo rebotado al remitente`: 
  Esta es la dirección que aparecerá como remite en notificaciones enviadas al
  emisor, como las generadas cuando se excede el tamaño limite del buzón.
:guilabel:`Tamaño máximo de buzón`: 
  En esta opción se puede indica un tamaño máximo en MiB para los buzones del
  usuario. Todo el correo que exceda el limite sera rechazado y el remitente
  recibirá una notificación. Esta opción puede sustituirse para cada usuario en
  la pagina :menuselection:`Usuarios -> Editar Usuario`.
:guilabel:`Tamaño máximo aceptado para los mensajes`:
  Señala, si es necesario, el tamaño máximo de mensaje aceptado por el
  *smarthost* en MiB. Esta opción tendrá efecto sin importar la existencia o no
  de cualquier limite al tamaño del buzón de los usuarios.
:guilabel:`Periodo de expiración para correos borrados`: 
  si esta opción esta activada el correo en la carpeta de papelera de los
  usuarios sera borrado cuando su fecha sobrepase el limite de días.
:guilabel:`Periodo de expiración para correo de spam`: 
   funciona igual que la opción anterior pero faceta a la carpeta de spam de los usuarios.

Se puede también configurar la obtención de los mensajes en la sección
guilabel:`Servicios de obtención de correo`. eBox puede configurarse
como servidor de POP3 o/y IMAP, sus versiones seguras POP3S y IMAPS  también
están disponibles.
En esta sección también pueden activarse los servicios para obtener correo de
direcciones externas y ManageSieve, estos servicios se explicaran en sus propias secciones.

También se puede configurar eBox para que permita reenviar correo sin necesidad
de autenticarse desde determinadas direcciones de red. Para
ello se permite una política de reenvío con objetos de red de eBox a
través de :menuselection:`Correo --> General --> Política de Relay sobre objetos`
basándonos en la dirección IP del servidor de correo origen. Si se
permite el reenvío de correos desde dicho objeto, cualquier miembro de
dicho objeto podrá enviar correos a través de eBox.

.. image:: images/mail/02-relay.png

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

Para crear cuentas de correo lo haremos de manera análoga a la compartición de
ficheros, acudimos a
:menuselection:`Usuarios y Grupos --> Usuarios --> Editar Usuario --> Crear cuenta de correo`.
Es ahí donde seleccionamos el dominio virtual principal del usuario. Si
queremos asignar al usuario a más de una cuenta de correo lo podemos hacer a
través de los alias. Indiferentemente de si se ha usado un alias o no, el correo
sera almacenado una única vez en el buzón del usuario.
sin embargo, no es posible usar un alias para autenticarse, se debe usar siempre
la cuenta normal.

Te en cuenta que puedes decidir si deseas que a un usuario se le cree
automáticamente una cuena de correo cuando se crea. Este comportamiento
puede ser configurado en `Usuarios y Grupos -> Plantilla de Usuario por
defecto --> Cuenta de correo`.

.. image:: images/mail/03-user.png
   :align: center
   :scale: 80

De la misma manera, se pueden crear *alias* para grupos. Los mensajes recibidos
por estos alias son enviado a todo los usuarios del grupo con cuenta de
correo. Los alias de grupo son creados a  través de :menuselection:`Usuarios y Grupos --> Grupos -->
Editar grupo --> Crear un alias de cuenta de correo al grupo`.  Los alias de
grupo están solo disponibles cuando al menos un usuario del grupo tiene cuenta
de correo.

También es posible definir alias hacia cuentas externas. El correo enviado a
un alias sera reenviado a las correspondiente cuenta externa. Esta clase de alias
se establecen por dominio virtual de correo, no requieren la existencia de
ninguna cuenta de correo y pueden establecerse en  :menuselection:`Correo --> Dominios Virtuales --> Alias a cuentas externas`.


Gestión de cola
---------------

Desde :menuselection:`Correo --> Gestión de cola` podemos ver los correos que
todavía no han sido enviados con la información acerca del mensaje. Las
acciones que podemos realizar con estos mensajes son: eliminarlos, ver
su contenido o volver a tratar de enviarlos (*reencolarlos*). También hay dos
botones para borrar o reencolar  todos los mensajes en la cola.

.. image:: images/mail/04-queue.png
   :align: center

Obtención de correo desde cuentas externas
----------------------------------------------

eBox puede ser configurado para recoger correo de cuentas externas y enviarlo a
los buzones de los usuarios. Para permitir esto, en :guilabel:`Servicios de
obtención de correo`. Una vez activado el correo de los usuarios sera obtenido
desde sus cuentas externas y enviado al buzón de su cuenta interna. Cada usuario
puede configurar sus cuentas externas a través del rincón del usuario. El
usuario debe tener una cuenta de correo para poder hacer esto. Los servidores
externos son consultados periódicamente, así que la obtención del correo no es
instantánea.

Para obtener el correo externo, eBox usa Fetchmail [#f3]_ .

.. rubric:: Footnotes

.. [#f3] **Fetchmail** The Fetchmail Home Page http://fetchmail.berlios.de/ .




Scripts Sieve  y protocolo ManageSieve 
---------------------------------------
El lenguaje Sieve [#f4]_ permite el control al usuario de como su correo es
recibido, permitiendo, entre otras cosas, clasificarlo en carpetas IMAP, reenviarlo o el uso de un
mensaje de vacaciones.

ManageSieve es un protocolo de red que permite a los usuarios gestionar sus
scripts Sieve. Para usarlo, es necesario que el cliente de correo pueda entender
el protocolo [#f5]_ .

Para usar ManageSieve en eBox, debes activar el servicio en
:menuselection:`Correo--> General --> Opciones de servidor de coreo -> Servicios
de obtención de correo`  y podrá ser usado por todos los usuarios con cuenta de
correo. Adicionalmente si ManageSieve esta activado y el modulo de correo web en
uso una interfaz de gestión para scripts Sieve estará disponible en el correo web.

La autenticación en ManageSieve se hace con la cuenta de correo del usuario y su contraseña.




.. rubric:: Footnotes

.. [#f4] Para mas informacion sobre Sieve http://sieve.info/ .
.. [#f5] Para tener una lista de clientes Sieve http://sieve.info/clients .


Configuración del cliente de correo
-----------------------------------
A no ser que los usuarios solo usen el correo a través de los módulos de
egroupware o de correo web, deberán configurar su cliente de coreo para usar el
servidor de correo de eBox. El valor de los parámetros necesarios dependerán de
la configuración del servicio de correo.

Hay que tener en cuenta que diferentes clientes de correo podrán usar distintos
nombres para estos parámetros, por lo que debido a la multitud de clientes
existente esta sección es orientativa.



Parámetros SMTP 
=================
 * Servidor SMTP: En este parámetro se debe introducir la dirección del servidor
   eBox. La dirección puede ser introducida como dirección IP o como nombre de
   dominio. 
 * Puerto SMTP: 25, si usas TLS puedes usar en su lugar el puerto 465.
 * Conexión segura: Debes seleccionar `TLS` si tienes activada la opción
   :guilabel:`TLS para el servidor SMTP`, en otro caso selecciona `ninguna`. Si
   usas TLS lee la advertencia de mas abajo sobre TLS/SSL.
 * Usuario SMTP: Como nombre de usuario se debe usar la dirección de correo
   completa del usuario, no uses su nombre de usuario o alguno de sus alias de
   correo. 
 * Contraseña SMTP: es la misma que la contraseña del usuario.


Parámetros POP3
================
Solo puedes usar configuración POP3 cuando el servicio POP3 o POP3S esta
activados en eBox.
 * Servidor POP3: introduce la dirección de eBox, como en el servidor SMTP.
 * Puerto POP3: 110, 995 en el caso de usar POP3S.
 * Conexión segura: selecciona `SSL` en caso de que uses POP3S, `ninguno` si
   usas POP3. Si usas POP3S lee la advertencia de mas abajo sobre TLS/SSL.
 * Usuario POP3: dirección de correo completa del usuario
 * Contraseña: es la misma que la contraseña del usuario

Parámetros IMAP
===============
solo se puede usar la configuración IMAP si el servicio IMAP o IMAPS esta
activo. 
 * Servidor IMAP: introduce la dirección de eBox, como en el servidor SMTP.
 * Puerto IMAP: 443, 993 en el caso de usar IMAPS.
 * Conexión segura: selecciona `SSL` en caso de que uses IMAPS, `ninguno` si
   usas IMAP. Si usas IMAPS lee la advertencia de mas abajo sobre TLS/SSL.
 * Usuario IMAP: dirección de correo completa del usuario
 * Contraseña: es la misma que la contraseña del usuario



.. warning::

En las implementaciones en los clientes de correo aveces hay confusión sobre el
uso de los protocolos SSL y TLS. Algunos clientes usan `SSL` para indicar que
van a conectar con `TLS`, otros usan `TLS` para indicar que van a tratar de
conectar al servicio a través de un puerto tradicionalmente usado por las
versiones del protocolo en claro. De hecho, en algunos clientes hará falta
probar tanto los modos `SSL` como `TLS` para hallar cual funciona.

Tienes mas información sobre este asunto en el wiki de Dovecot,
http://wiki.dovecot.org/SSL .




Parámetros para ManageSieve 
=============================
Para conectar a ManageSieve, necesitaras los siguientes parámetros:
 * Servidor Sieve: el mismo que tu servidor IMAP o POP3.
 * Puerto: 4190. Hay que tener en cuenta que algunas aplicaciones usan, por error
   el puerto 2000 como puerto por defecto para ManageSieve.
 * Conexión segura: activar esta opción.
 * Nombre de usuario: dirección de correo completa
 * Contraseña: contraseña del usuario. Algunos clientes permiten indicar que se
   va a usar la misma autenticación que para IMAP o POP, si esto es posible
   seleccionarlo. 

Cuenta para recoger todo el correo
------------------------------------

Una cuenta para recoger todo el correo es una cuenta que recibe una copia de
todo el correo enviado y recibido por un dominio de correo. eBox permite definir
una de estas cuentas por cada dominio; para establecerla se debe ir a la pagina 
:menuselection:`Correo --> Dominios Virtuales` y después hacer click en la celda
:guilabel:`Opciones`.

Todos los mensajes enviados y recibidos por el dominio serán enviados como copia
oculta a la dirección definida. Si la dirección rebota el correo, sera retornado
al remitente.



.. _mail-conf-exercise-ref:

Ejemplo práctico
^^^^^^^^^^^^^^^^
Crear un dominio virtual para el correo. Crear una cuenta de usuario y una
cuenta de correo en el dominio creado para dicho usuario. Configurar el
*relay* para el envío de correo. Enviar un correo de prueba con la cuenta
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
   Acceder a :menuselection:`Usuarios y Grupos --> Uusarios --> Añadir usuario`,
   rellenar sus datos y pulsar el botón :guilabel:`Crear`.

   Efecto:
     El usuario se añade inmediatamente sin necesidad de salvar cambios.
     Aparece la pantalla de edición del usuario recién creado.

#. **Acción:**
    (Este paso solo es necesario si has deshabilitado la opción de crear
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
