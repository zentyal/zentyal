Servicio de Voz sobre IP
*************************

.. sectionauthor:: Enrique J. Hernández <ejhernandez@ebox-platform.com>
                   Jorge Salamero <jsalamero@ebox-platform.com>

La **Voz sobre IP** o **Voz IP** consiste en transmitir voz sobre redes de datos usando
una serie de protocolos para enviar la señal digital en paquetes en
lugar de enviarla a través de circuitos analógicos conectados.

Cualquier red IP puede ser utilizada para esto, desde redes locales hasta
redes públicas como *Internet*. Esto conlleva un ahorro importante de costes al
utilizar una misma red para llevar voz y datos, sin escatimar en calidad o
fiabilidad. Los principales problemas que se encuentra la Voz IP en su
despliegue sobre las redes de datos son el NAT [#]_ y las dificultades que tienen
los protocolos para gestionarlo, y el QoS [#]_, la necesidad de ofrecer un servicio
de calidad en tiempo real, considerando la latencia (tiempo que se tarda en
llegar al destino), el *jitter* (la variación de la latencia) y el ancho de
banda.

.. [#] Concepto que se explica en la sección :ref:`firewall-ref`.

.. [#] Concepto que se explica en la sección :ref:`qos-ref`.

Protocolos
----------

Son varios los protocolos involucrados en la transmisión de voz, desde los
protocolos de red como IP, con los protocolos de transporte como UDP o TCP,
hasta los protocolos de voz, tanto para su transporte como para su
señalización.

Los **protocolos de señalización** en Voz IP desempeñan las tareas de
establecimiento y control de la llamada. SIP, IAX2 y H.323 son protocolos de
señalización.

El **protocolo de transporte de voz** más utilizado es RTP (*Realtime Transport
Protocol*) y su tarea es transportar la voz codificada desde el origen hasta
el destino. Este protocolo se pone en marcha una vez establecida la llamada
por los protocolos de señalización.

SIP
^^^
**SIP** o *Session Initiation Protocol* es un protocolo creado en el
seno del IETF [#]_ para la iniciación, modificación y finalización de
sesiones interactivas multimedia. Tiene gran similitud con HTTP y
SMTP. SIP solamente se encarga de la señalización funcionando sobre el
puerto UDP/5060. La transmisión multimedia se realiza con RTP sobre el
rango de puertos UDP/10000-20000.

.. [#] **Internet Engineering Task Force** desarrolla y promociona
       estándares de comunicaciones usados en *Internet*.

.. TODO: explicar funcionamiento de SIP y SIP+NAT
.. TODO: protocolo H323

IAX2
^^^^
**IAX2** es la versión 2 del protocolo *Inter Asterisk eXchange* creado para la
interconexión de centralitas *Asterisk* [#]_. Las características más importantes
de este protocolo es que la voz y la señalización va por el mismo flujo de
datos y además éste puede ser cifrado. Esto tiene la ventaja directa de poder
atravesar NAT con facilidad y que la sobrecarga es menor a la hora de mantener
varios canales de comunicación simultáneos entre servidores. IAX2 funciona
sobre el puerto UDP/4569.

.. [#] **Asterisk** es un *software* para centralitas telefónicas que
       eBox usa para implementar el módulo de Voz IP <http://www.asterisk.org/>.

Códecs
------

Un **códec** es un algoritmo que adapta (codificando en origen y
descodificando en destino) una información digital con el objetivo de
comprimirla reduciendo el uso de ancho de banda y detectando y
recuperándose de los errores en la transmisión. G.711, G.729, GSM y
speex son códecs habituales dentro de la Voz IP.

**G.711**:
  Es uno de los códecs más utilizados, con dos versiones, una
  americana (*ulaw*) y otra europea (*alaw*). Este códec ofrece buena
  calidad pero su consumo de ancho de banda es bastante significativo
  con 64kbps. Es el más habitual para la comunicación por voz en redes locales.

**G.729**:
  Tiene una compresión mucho mayor usando solamente 8kbps siendo
  ideal para las comunicaciones a través de *Internet*. El inconveniente es que
  tiene algunas restricciones en su uso.

**GSM**:
  Es el mismo códec que el usado en las redes de telefonía celular. La
  calidad de voz no es muy buena y usa 13kbps aproximadamente.

**speex**:
  Es un códec libre de patentes diseñado para voz. Es muy flexible a
  pesar de consumir más tiempo de CPU que el resto y puede trabajar a
  distintas tasas de frecuencia desde 8KHz, 16KHz hasta 32KHz,
  normalmente referidos como *narrowband*, *wideband* y
  *ultra-wideband* respectivamente con un consumo de 15.2kbps, 28kbps
  y 36kbps.

.. TODO: hablar del overhead con las cabeceras
.. TODO: tabla con bitrate + %overhead + total

Despliegue
----------

Veamos los elementos implicados en el despliegue de Voz IP:

Teléfonos IP
^^^^^^^^^^^^
Son *teléfonos* con una apariencia convencional pero disponen
de un conector RJ45 para conectarlo a una red *Ethernet* en lugar
del habitual RJ11 de las redes telefónicas. Introducen
características nuevas como acceso a la agenda de direcciones,
automatización de llamadas, etc. no presentes en los teléfonos
analógicos convencionales.

.. figure:: images/voip/phone1.jpg
   :scale: 50
   :align: center
.. figure:: images/voip/phone2.jpg
   :scale: 50
   :align: center

Adaptadores Analógicos
^^^^^^^^^^^^^^^^^^^^^^
También conocidos como **adaptadores ATA** (*Analog Telephony
Adapter*), permiten conectar un teléfono analógico convencional a una
red de datos IP y hacer que este funcione como un teléfono IP. Para
ello dispone de un puerto de red de datos RJ45 y uno o más puertos
telefónicos RJ11.

.. figure:: images/voip/ata.jpg
   :scale: 40
   :align: center

Softphones
^^^^^^^^^^
Los **softphones** son aplicaciones de ordenador que permiten realizar llamadas
Voz IP sin más *hardware* adicional que los propios altavoces y micrófono
del ordenador. Existen multitud de aplicaciones para este propósito, para
todas las plataformas y sistemas operativos. X-Lite y QuteCom (WengoPhone)
están disponibles tanto para Windows y OSX como para GNU/Linux. Ekiga
(GnomeMeeting) o Twinkle son nativas de este último.

.. figure:: images/voip/qutecom.png
   :scale: 40
   :align: center

   Qutecom

.. figure:: images/voip/twinkle.png
   :scale: 40
   :align: center

   Twinkle

Centralitas IP
^^^^^^^^^^^^^^
A diferencia de la telefonía tradicional, dónde las llamadas pasaban siempre
por la centralita, en la Voz IP los clientes (teléfonos IP o *softphones*) se
registran en el servidor, el emisor pregunta por los datos del receptor al
servidor, y entonces el primero realiza una llamada al receptor. En el
establecimiento de la llamada negocian un códec común para la transmisión
de la voz.

*Asterisk* es una aplicación exclusivamente *software* que funciona sobre cualquier
servidor habitual proporcionando las funcionalidades de una centralita o PBX
(*Private Branch eXchange*): conectar entre sí distintos teléfonos, a un proveedor
de Voz IP, o bien a la red telefónica. También ofrece servicios como buzón de voz,
conferencias, respuesta interactiva de voz, etc.

Para conectar el servidor de la centralita *Asterisk* a la red telefónica analógica
se usan unas tarjetas llamadas FXO (*Foreign eXchange Office*) que permiten a *Asterisk*
funcionar como si fuera un teléfono convencional y redirigir las llamadas a través
de la red telefónica. Para conectar un teléfono analógico al servidor se debe usar
una tarjeta FXS (*Foreign eXchange Station*) así se pueden adaptar los terminales
existentes a una nueva red de telefonía IP.

.. figure:: images/voip/tdm422e.png
   :scale: 30

   Digium TDM422E FXO and FXS card

Configuración de un servidor *Asterisk* con eBox
------------------------------------------------
El módulo de Voz IP de eBox permite gestionar un servidor *Asterisk* con los
usuarios ya existentes en el servidor LDAP del sistema y con las
funcionalidades más habituales configuradas de una forma sencilla.

.. figure:: images/voip/deployment.png
   :scale: 50

Como ya es habitual, en primer lugar deberemos habilitar el
módulo. Iremos a la sección :menuselection:`Estado del Módulo` del
menú de eBox y seleccionaremos la casilla :guilabel:`Voz IP`. Si no
tenemos habilitado el módulo :guilabel:`Usuarios y Grupos` deberá ser
habilitado previamente ya que depende de él.

.. figure:: images/voip/ebox-asterisk_general.png
   :scale: 50

A la configuración general del servidor se accede a través del menú
:menuselection:`Voz IP --> General`, una vez allí sólo necesitamos
configurar los siguientes parámetros generales:

:guilabel:`Habilitar extensiones demo`:
  Habilita las extensiones 400, 500 y 600. Si llamamos a la extensión
  400 podremos escuchar la música de espera, llamando a la 500
  se realiza una llamada mediante el protocolo IAX a
  guest@pbx.digium.com. En la extensión 600 se dispone de una *prueba
  de eco* para darnos una idea de la latencia en las llamadas. En
  definitiva estas extensiones nos permiten comprobar que nuestro
  cliente esta correctamente configurado.

:guilabel:`Habilitar llamadas salientes`:
  Habilita las llamadas salientes a través del proveedor SIP que tengamos
  configurado para llamar a teléfonos convencionales. Para realizar
  llamadas a través del proveedor SIP tendremos que añadir un cero
  adicional antes del número a llamar, por ejemplo si queremos llamar
  a las oficinas de eBox Technologies (+34 976733506, o mejor
  0034976733506), pulsaríamos 00034976733506.

:guilabel:`Extensión de buzón de voz`:
  Es la extensión donde podemos consultar nuestro buzón de voz. El
  usuario y la contraseña es la extensión adjudicada por eBox al crear
  el usuario o al asignársela por primera vez. Recomendamos cambiar la
  contraseña inmediatamente desde el **Rincón del Usuario** [#]_. La aplicación
  que reside en esta extensión nos permite cambiar el mensaje de
  bienvenida a nuestro buzón, escuchar los mensajes en él y
  borrarlos. Esta extensión solamente es accesible por los usuarios de
  nuestro servidor, no aceptará llamadas entrantes de otros servidores
  por seguridad.

.. [#] **El Rincón del Usuario** se explica en la sección :ref:`usercorner-ref`.

:guilabel:`Dominio Voz IP`:
  Es el dominio que se asignará a las direcciones de nuestros
  usuarios. Así pues un usuario **usuario**, que tenga una extensión 1122
  podrá ser llamado a usuario@dominio.tld o 1122@dominio.tld.

En la sección de :guilabel:`Proveedor SIP` introduciremos los datos
suministrados por nuestro proveedor SIP para que eBox pueda redirigir
las llamadas a través de él:

:guilabel:`Proveedor`:
  Si estamos usando :guilabel:`eBox VoIP Credit` [#]_, seleccionaremos esta opción
  que preconfigurará el nombre del proveedor y el servidor. En otro caso usaremos
  :guilabel:`Personalizado`.
:guilabel:`Nombre`:
  Es el identificador que se da al proveedor dentro de eBox.
:guilabel:`Nombre de usuario`:
  Es el nombre de usuario del proveedor.
:guilabel:`Contraseña`:
  Es la contraseña de usuario del proveedor.
:guilabel:`Servidor`:
  Es el nombre de dominio del servidor del proveedor.
:guilabel:`Destino de las llamadas entrantes`:
  Es la extensión interna a la que se redirigen las llamadas realizadas
  a la cuenta del proveedor.

.. [#] Puedes comprar **eBox VoIP credit** en nuestra tienda_.

.. _tienda: http://store.ebox-technologies.com/?utm_source=doc_es

En la sección de :guilabel:`Configuración NAT` definiremos la posición
en la red de nuestra máquina eBox. Si tiene una IP pública la opción
por defecto :guilabel:`eBox está tras NAT: No` es correcta. Si
tiene una IP privada deberemos indicar a *Asterisk* cuál es la IP
pública que obtenemos al salir a *Internet*. En caso de tener una IP
pública fija simplemente la introduciremos en :guilabel:`Dirección IP
fija`; si nuestra IP pública es dinámica tendremos que configurar
el servicio de DNS dinámico (DynDNS) de eBox disponible en
:menuselection:`Red --> DynDNS` (o configurarlo
manualmente) e introduciremos el nombre de dominio en
:guilabel:`Nombre de máquina dinámico`.

En la sección de :guilabel:`Redes locales` podremos añadir las redes
locales a las que accedemos desde eBox sin hacer NAT, como pueden ser
redes VPN, u otra serie de segmentos de red no configurados desde
eBox como pudiera ser una red wireless. Esto es necesario debido al
comportamiento del protocolo SIP en entornos con NAT.

A la configuración de las conferencias se accede a través
:menuselection:`Voz IP --> Conferencias`. Aquí podemos configurar salas
de reunión multiconferencia.  La :guilabel:`extensión` de estas salas
deberá residir en el rango 8001-8999 y podrán tener opcionalmente una
:guilabel:`contraseña de entrada`, una :guilabel:`contraseña
administrativa` y una :guilabel:`descripción`. A estas extensiones se
podrá acceder desde cualquier servidor simplemente marcando
extension@dominio.tld.

.. figure:: images/voip/ebox-asterisk_meetings.png
   :scale: 80

Cuando editemos un usuario, podremos habilitar o deshabilitar la cuenta de VozIP de este usuario y
cambiar su extensión. Hay que tener en cuenta que una extensión sólamente puede asignarse a un usuario
y no a más, si necesitas llamar a más de un usuario desde una extensión será necesario utilizar colas.

.. figure:: images/voip/ebox-asterisk_user.png
   :scale: 80

Cuando editemos un grupo, podremos habilitar o deshabilitar la cola de
este grupo. Una **cola** es una extensión dónde al recibir una
llamada, se llama a todos los usuarios que pertenecen a este grupo.

.. figure:: images/voip/ebox-asterisk_group.png
   :scale: 80

Si queremos configurar la música de espera, colocaremos las canciones en formato MP3 en
`/var/lib/asterisk/mohmp3/` e instalaremos el paquete *mpg123*.

Configurando un *softphone* para conectar a eBox
------------------------------------------------

Ekiga (Gnome)
^^^^^^^^^^^^^

**Ekiga** [#]_ es el *softphone* o cliente de voz IP recomendado en el
*entorno de escritorio Gnome*. Al lanzarlo por primera vez
presenta un asistente para configurar datos personales del usuario,
dispositivos de sonido y vídeo, la conexión a *Internet* y los
servicios de *Ekiga.net*. Podemos omitir la configuración tanto de la
cuenta en *Ekiga.net* como de *Ekiga Call Out*.

.. [#] Ekiga: *Free your speech* <http://ekiga.org/>

Desde :guilabel:`Editar --> Cuentas`, seleccionando :guilabel:`Cuentas
--> Añadir una cuenta SIP` podremos configurar la cuenta de Voz IP de
eBox Platform.

:guilabel:`Nombre`:
  Es el identificador de la cuenta dentro de *Ekiga*.
:guilabel:`Servidor de registro`:
  Es el nombre de dominio del servidor de Voz IP de eBox.
:guilabel:`Usuario` y :guilabel:`Usuario para autenticación`:
  Son el nombre de usuario de eBox.
:guilabel:`Contraseña`:
  Es la contraseña de usuario de eBox.

.. figure::        images/voip/ekiga_01.png
   :scale: 50
   :align: center

Tras configurar la cuenta se intentará registrar en el servidor.

.. figure:: images/voip/ekiga_02.png
   :scale: 50
   :align: center

Para realizar una llamada tan sólo hay que escribir el número o dirección *SIP*
en la barra superior y llamar usando el icono del teléfono verde a la derecha.
Para colgar se usa el icono del teléfono rojo a la derecha también.

.. figure:: images/voip/ekiga_03.png
   :scale: 50
   :align: center

Qutecom (Multiplataforma)
^^^^^^^^^^^^^^^^^^^^^^^^^

**Qutecom** [#]_ es un *softphone* que usa las bibliotecas Qt4 por lo que
está disponible en las tres plataformas más extendidas: Linux, OSX y
Windows. También al lanzarlo por primera vez nos presentará un
asistente para configurar la cuenta de Voz IP.

.. [#] QuteCom: *Free VOIP Softphone* http://www.qutecom.org

.. figure:: images/voip/qutecom_01.png
   :scale: 50
   :align: center

Tenemos un teclado numérico o una lista de contactos para realizar llamadas. Se
usan los botones verde / rojo en la parte inferior para llamar y colgar.

.. figure:: images/voip/qutecom_02.png
   :scale: 50
   :align: center

Usando las funcionalidades de eBox Voz IP
-----------------------------------------

Transferencia de llamadas
^^^^^^^^^^^^^^^^^^^^^^^^^

La **transferencia de llamadas** es muy sencilla. Durante el
transcurso de una conversación, pulsando :kbd:`#` y después introduciendo la
extensión a dónde queremos reenviar la llamada podremos realizar una
transferencia. En ese momento, podremos colgar ya que esta llamada
estará marcando la extensión a donde ha sido transferida.

Aparcamiento de llamadas
^^^^^^^^^^^^^^^^^^^^^^^^

El **aparcamiento de llamadas** se realiza sobre la extensión 700. Durante
el transcurso de una conversación, pulsaremos :kbd:`#` y después
marcaremos 700. La extensión donde la llamada ha sido aparcada será
anunciada a la parte llamada y quien estaba llamando comenzará a
escuchar la música de espera, si está configurada. Podremos colgar en
ese momento. Desde un teléfono distinto u otro usuario distinto
marcando la extensión anunciada podremos recoger la llamada aparcada y
restablecer la conversación.

En eBox, el aparcamiento de llamadas soporta 20 conversaciones y el periodo máximo que
una llamada puede esperar son 300 segundos.

Ejemplo práctico
^^^^^^^^^^^^^^^^

Crear un usuario que tenga una cuenta de Voz IP. Cambiarle la extensión a
1500.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activar el módulo :guilabel:`Voz IP` marcando la casilla
   correspondiente en la columna :guilabel:`Estado`. Si
   :guilabel:`Usuarios y Grupos` no está activado deberemos activarlo
   previamente pues depende de él. Entonces se informa sobre los cambios que
   se van a realizar en el sistema. Permitiremos la operación pulsando el botón
   :guilabel:`Aceptar`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Acceder al menú :menuselection:`Voz IP`. En el campo
   :guilabel:`Dominio Voz IP` escribir el nombre de dominio que corresponda
   a esta máquina. Este dominio deberá poder resolverse desde las máquinas
   de los clientes del servicio. Pulsar el botón :guilabel:`Cambiar`.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     El servicio de Voz IP está preparado para usarse.

#. **Acción:**

     Acceder al menú :menuselection:`Usuarios y Grupos --> Usuarios -->
     Añadir Usuario`. Completar la información del formulario para crear un
     nuevo usuario. Pulsar el botón :guilabel:`Crear Usuario`.

   Efecto:
     eBox crea un nuevo usuario y nos muestra el perfil con las opciones de
     este.

#. **Acción:**
   En la sección :guilabel:`Cuenta de Voz IP` muestra si el usuario tiene
   la cuenta activada o desactivada y la extensión que tiene asignada.
   Cerciorarse de que la cuenta está activada, ya que todos los usuarios creados
   mientras el módulo de Voz IP está habilitado tienen la cuenta activada. Por
   último, cambiar la extensión asignada por defecto, que es la primera libre
   del rango de extensiones de usuarios, a la extensión 1500 que deseábamos.
   Pulsar el botón :guilabel:`Aplicar cambios` de la sección
   :guilabel:`Cuenta de Voz IP`.

   Efecto:
     eBox aplica los cambios realizados inmediatamente, el usuario ya puede
     recibir llamadas sobre esa extensión.
