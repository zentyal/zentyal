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
correos por parte del usuario se realiza a través de POP3 o de IMAP
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
  Dirección IP o nombre de dominio
:guilabel:`Autenticación del smarthost`:
  Determinar si el *smarthost* requiere autenticación y si es así
  proveer un usuario y contraseña
:guilabel:`Tamaño máximo aceptado para los mensajes`:
  Señala, si es necesario, el tamaño máximo de mensaje aceptado por el
  *smarthost* en MiB.

Se puede también configurar la obtención de los mensajes en la sección
guilabel:`Servicios de obtención de correo`. EBox puede configurarse
como servidor de POP3 o IMAP, ambos con soporte SSL.

También se puede configurar eBox para que actúe como *smarthost*. Para
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
:menuselection:`Usuarios --> Editar Usuario --> Crear cuenta de correo`.
Es ahí donde seleccionamos el dominio virtual principal del usuario. Si
queremos asignar al usuario a más de una cuenta de correo lo podemos hacer a
través de los alias. Realmente, el correo es almacenado una única vez en el
buzón del usuario.

.. image:: images/mail/03-user.png
   :align: center
   :scale: 80

De la misma manera, se pueden crear *alias* para grupos donde recibir correo a
través de :menuselection:`Grupos --> Editar grupo --> Crear un alias de
cuenta de correo al grupo`.

.. FIXME: group mail alias account is required

Gestión de cola
---------------

Desde :menuselection:`Correo --> Gestión de cola` podemos ver los correos que
todavía no han sido enviados con la información acerca del mensaje. Las
acciones que podemos realizar con estos mensajes son: eliminarlos, ver
su contenido o volver a tratar de enviarlos (*reencolarlos*).

.. image:: images/mail/04-queue.png
   :align: center

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
   Acceder a :menuselection:`Usuarios --> Añadir usuario`,
   rellenar sus datos y pulsar el botón :guilabel:`Crear`.

   Efecto:
     El usuario se añade inmediatamente sin necesidad de salvar cambios.
     Aparece la pantalla de edición del usuario recién creado.

#. **Acción:**
   Escribir un nombre para la cuenta de correo del usuario en la sección
   :guilabel:`Crear cuenta de correo` y pulsar el botón :guilabel:`Crear`.

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
