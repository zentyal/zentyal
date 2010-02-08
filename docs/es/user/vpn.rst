****************************************
Interconexión segura entre redes locales
****************************************

.. sectionauthor:: Javier Amor García <javier.amor.garcia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   José A. Calvo <jacalvo@ebox-technologies.com>,
                   Jorge Salamero Sanz <jsalamero@ebox-technologies.com>

.. _vpn-ref:

Redes privadas virtuales (VPN)
==============================

Las **redes privadas virtuales** se idearon tanto para permitir el acceso
a la red corporativa por usuarios remotos a través de *Internet* como
para unir redes dispersas geográficamente.

Es frecuente que haya recursos necesarios para nuestros usuarios en
nuestra red, pero que dichos usuarios, al encontrarse fuera de nuestras
instalaciones no puedan conectarse directamente a ella. La
solución obvia es permitir la conexión a través de Internet. Esto nos
puede crear problemas de seguridad y configuración, los cuales se
tratan de resolver mediante el uso de las **redes privadas virtuales**.

La solución que ofrece una VPN (*Virtual Private Network*) a este
problema es el uso de cifrado para permitir sólo el acceso a los
usuarios autorizados (de ahí el adjetivo privada). Para facilitar el
uso y la configuración, las conexiones aparecen como si existiese una
red entre los usuarios (de ahí lo de virtual).

La utilidad de las VPN no se limita al acceso remoto de los usuarios;
una organización puede desear conectar entre sí redes que se
encuentran en sitios distintos. Por ejemplo, oficinas en distintas
ciudades. Antes, la solución a este problema estaba en la contratación
de líneas dedicadas para conectar dichas redes, este servicio es
costoso y lento de desplegar. Sin embargo, el avance de Internet
proporcionó un medio barato y ubicuo, pero inseguro. De nuevo las
características de autorización y virtualización de las VPN resultaron la
respuesta adecuada a dicho problema.

A este respecto, **eBox** ofrece dos modos de funcionamiento. Permite funcionar
como servidor para usuarios individuales y también como
conexión entre dos o más redes gestionadas con eBox.

Infraestructura de clave pública (PKI) con una autoridad de certificación (CA)
==============================================================================

La VPN que usa eBox para garantizar la privacidad e integridad de los datos
transmitidos utiliza cifrado proporcionado por tecnología SSL. La
tecnología SSL está extendida y lleva largo tiempo en uso, así que
podemos estar razonablemente seguros de su eficacia. Sin embargo, todo
mecanismo de cifrado tiene el problema de cómo distribuir las claves
necesarias a los usuarios, sin que estas puedan ser interceptadas por
terceros. En el caso de las VPN, este paso es necesario cuando un
nuevo participante ingresa en la red privada virtual.
La solución adoptada es el uso de una infraestructura de clave
pública (*Public Key Infraestructure* - PKI). Esta tecnología nos
permite la utilización de claves en un medio inseguro, como es el caso
de *Internet*, sin que sea posible la interceptación de la clave por
observadores de la comunicación.

La **PKI** se basa en que cada participante genera un par de
claves: una *pública* y una *privada*. La *pública* es distribuida y la
*privada* guardada en secreto. Cualquier participante que quiera cifrar
un mensaje puede hacerlo con la *clave pública* del destinatario, pero
el mensaje sólo puede ser descifrado con la *clave privada* del
mismo. Como esta última no debe ser comunicada a nadie nos
aseguramos que el mensaje sólo pueda ser descifrado por el
destinatario. No obstante, esta solución engendra un nuevo
problema. ¿Si cualquiera puede presentar una *clave pública*, cómo
garantizamos que un participante es realmente quien dice ser y no está
suplantando una identidad que no le corresponde?. Para resolver este
problema, se crearon los **certificados**. [#]_

.. [#] Existe mucha documentación sobre el cifrado basado en clave
       pública. Este enlace puede ser un comienzo:
       http://en.wikipedia.org/wiki/Public-key_encryption

.. figure:: images/vpn/public-key-encryption.png
   :alt: Cifrado con clave pública
   :scale: 40

   *GRAPHIC: Cifrado con clave pública*

.. figure:: images/vpn/public-key-signing.png
   :alt: Firmado con clave pública
   :scale: 40

   *GRAPHIC: Firmado con clave pública*

Los **certificados** aprovechan otra capacidad de la **PKI**: la
posibilidad de firmar ficheros. Para firmar ficheros se usa la propia
*clave privada* del firmante y para verificar la firma cualquiera puede
usar la *clave pública*. Un **certificado** es un fichero que contiene una
*clave pública*, firmada por un participante en el que confiamos. A este
participante en el que depositamos la confianza de verificar las
identidades se le denomina **autoridad de certificación**
(*Certification Authority* - CA).

.. figure:: images/vpn/public-key-certificate.png
   :scale: 60
   :alt: Diagram to issue a certificate

   *GRAPHIC: Diagram to issue a certificate*

Configuración de una Autoridad de Certificación con eBox
========================================================

eBox tiene integrada la gestión de la Autoridad de Certificación y del
ciclo de vida de los certificados expedidos por esta para tu organización.
Utiliza las herramienta de consola **OpenSSL** [#]_ para este servicio.

.. [#] **OpenSSL** - *The open source toolkit for SSL/TLS* <http://www.openssl.org/>.

Primero, es necesario generar las claves y expedir el certificado de la *CA*.
Este paso es necesario para firmar nuevos certificados, así que el resto de
funcionalidades del módulo no estarán disponibles hasta que las claves de la
*CA* se generen y su certificado, que es auto firmado, sea expedido. Téngase
en cuenta que este módulo es independiente y no necesita ser activado en
:guilabel:`Estado del Módulo`.

.. image:: images/vpn/ebox-ca-01.png
   :align: center
   :scale: 80

Accederemos a :menuselection:`Autoridad de Certificación --> General` y nos
encontraremos ante el formulario para expedir el certificado de la *CA* tras
generar automáticamente el par de claves. Se requerirá el
:guilabel:`Nombre de la Organización` y el :guilabel:`Número de
Días para Expirar`. A la hora de establecer la duración hay que tener en cuenta
que su expiración revocará todos los certificados expedidos por esta *CA*,
provocando la parada de todos los servicios que dependan de estos certificados.
También es posible dar los siguientes datos de manera opcional:

:guilabel:`Código del País`
  Un acrónimo de dos letras que sigue el estándar ISO-3166.

:guilabel:`Ciudad`

:guilabel:`Estado o Región`

.. image:: images/vpn/ebox-ca-02.png
   :align: center
   :scale: 80

Una vez que la *CA* ha sido creada, seremos capaces de expedir certificados
firmados por esta *CA*. Para hacer esto, usaremos el formulario que aparece
ahora en :menuselection:`Autoridad de Certificación --> General`. Los datos
necesarios son el :guilabel:`Nombre Común` del certificado y los :guilabel:`Días
para Expirar`. Este último dato está limitado por el hecho de que ningún
certificado puede ser válido durante más tiempo que la *CA*. En el caso de
que estemos usando estos certificados para un servicio como podría ser
un servidor web o un servidor de correo, el :guilabel:`Nombre Común` deberá
coincidir con el nombre de dominio del servidor.

Una vez el certificado haya sido creado, aparecerá en la lista de
certificados y estará disponible para los módulos de eBox que usen
certificados y para las demás aplicaciones externas. Además, a través de la
lista de certificados podemos realizar distintas acciones con ellos:

- Descargar las claves pública, privada y el certificado.
- Renovar un certificado.
- Revocar un certificado.

Si renovamos un certificado, el certificado actual será revocado y uno
nuevo con la nueva fecha de expiración será expedido junto al par de claves.

.. image:: images/vpn/ebox-ca-03.png
   :align: center
   :scale: 80

Si revocamos un certificado no podremos utilizarlo más ya que esta acción
es permanente y no se puede deshacer. Opcionalmente podemos seleccionar
la razón para revocarlo:

:guilabel:`unspecified`
  Motivo no especificado

:guilabel:`keyCompromise`
  La clave privada ha sido comprometida

:guilabel:`CACompromise` 
  La clave privada de la autoridad de certificación ha sido comprometida

:guilabel:`affilliationChanged` 
  Se ha producido un cambio en la afiliación de la clave pública
  firmada hacia otra organización.

:guilabel:`superseded`
  El certificado ha sido renovado y por tanto reemplaza al emitido.

:guilabel:`cessationOfOperation`
  Cese de operaciones de la entidad certificada.

:guilabel:`certificateHold`
  Certificado suspendido.

:guilabel:`removeFromCRL`
  Actualmente sin implementar da soporte a los *CRLs* delta o
  diferenciales.

.. image:: images/vpn/ebox-ca-04.png
   :align: center
   :scale: 80

Si se renueva la *CA*, todos los certificados se renovarán con la nueva
*CA* tratando de mantener la antigua fecha de expiración, si esto no es
posible debido a que es posterior a la fecha de expiración de la *CA*,
entonces se establecerá la fecha de expiración de la *CA*.

Cuando un certificado expire, el resto de módulos serán notificados. La
fecha de expiración de cada certificado se comprueba una vez al día y cada
vez que se accede al listado de certificados.

Certificados de Servicios
^^^^^^^^^^^^^^^^^^^^^^^^^

.. image:: images/vpn/ebox-ca-05.png
   :align: center
   :scale: 80

En :menuselection:`Autoridad de Certificación --> Certificados de Servicios` 
podemos encontrar la lista de módulos de eBox usando certificados para sus
servicios. Por omisión estos son generados por cada módulo, pero si estamos
usando la *CA* podemos remplazar estos certificados auto firmados por uno
expedido por la *CA* de nuestra organización. Para cada servicio podemos
definir el :guilabel:`Nombre Común` del certificado y si no hay un certificado
con ese :guilabel:`Nombre Común`, la *CA* expedirá uno. Para ofrecer este
par de claves y el certificado firmado al servicio deberemos :guilabel:`Activar`
el certificado para ese servicio.

Cada vez que un certificado se renueva se ofrece de nuevo al módulo de eBox
pero es necesario reiniciar ese servicio para forzarlo a usar el nuevo
certificado.

Ejemplo práctico A
^^^^^^^^^^^^^^^^^^

Crear una autoridad de certificación (*CA*) válida durante un año, después
crear un certificado llamado *servidor* y crear dos certificados para clientes
llamados *cliente1* y *cliente2*.

#. **Acción:**
   En :menuselection:`Autoridad de Certificación --> General`, en el
   formulario :guilabel:`Expedir el Certificado de la Autoridad de
   Certificación` rellenamos los campos :guilabel:`Nombre de la
   Organización` y :guilabel:`Días para Expirar` con valores razonables.
   Pulsamos :guilabel:`Expedir` para generar la Autoridad de Certificación.

   Efecto:
    El par de claves de la Autoridad de Certificación es generados y su
    certificado expedido. La nueva *CA* se mostrará en el listado de
    certificados. El formulario para crear la Autoridad de Certificación
    será sustituido por uno para expedir certificados normales.

#. **Acción:**
    Usando el formulario :guilabel:`Expedir un Nuevo Certificado` para
    expedir certificados, escribiremos *servidor* en :guilabel:`Nombre Común`
    y en :guilabel:`Días para Expirar` un número de días menor o igual que
    el puesto en el certificado de la *CA*. Repetiremos estos pasos con los
    nombres *cliente1* y *cliente2*.

   Efecto:
    Los nuevos certificados aparecerán en el listado de certificados,
    listos para ser usados.

Configuración de una VPN con eBox
=================================

El producto seleccionado por eBox para crear las VPN es
**OpenVPN** [#]_. OpenVPN posee las siguientes ventajas:

 - Autenticación mediante infraestructura de clave pública.
 - Cifrado basado en tecnología SSL.
 - Clientes disponibles para Windows, MacOS y Linux.
 - Código que se ejecuta en espacio de usuario, no hace falta
   modificación de la pila de red (al contrario que con **IPSec**).
 - Posibilidad de usar programas de red de forma transparente.

.. [#] **OpenVPN**: *An open source SSL VPN Solution by James
       Yonan* http://openvpn.net.

Cliente remoto con VPN
^^^^^^^^^^^^^^^^^^^^^^

Se puede configurar eBox para dar soporte a clientes remotos
(conocidos familiarmente como *Road Warriors*). Esto es, una máquina
eBox trabajando como puerta de enlace y como servidor OpenVPN, que
tiene una red de área local (LAN) detrás, permitiendo a clientes en
*Internet* (los *road warriors*) conectarse a dicha red local vía
servicio VPN.

La siguiente figura puede dar una visión más ajustada:

.. figure:: images/vpn/road-warrior.png
   :scale: 70
   :alt: eBox y clientes remotos de VPN

   eBox y clientes remotos de VPN

Nuestro objetivo es conectar al cliente 3 con los otros 2 clientes
lejanos (1 y 2) y estos últimos entre sí.

Para ello, necesitamos crear una **Autoridad de Certificación** y
certificados para los dos clientes remotos. Tenga en cuenta que también se
necesita un certificado para el servidor OpenVPN. Sin embargo, eBox creará este
certificado automáticamente cuando cree un nuevo servidor OpenVPN. En este
escenario, eBox actúa como una **Autoridad de Certificación**.

Una vez tenemos los certificados, deberíamos poner a punto el servidor
OpenVPN en eBox mediante :guilabel:`Crear un nuevo servidor`. El único parámetro
que necesitamos introducir para crear un servidor es el nombre. eBox hace que la
tarea de configurar un servidor OpenVPN sea sencilla, ya que establece valores
de forma automática.

Los siguientes parámetros de configuración son añadidos
automáticamente por eBox, y pueden ser modificados si es necesario:
una pareja de :guilabel:`puerto/protocolo`, un :guilabel:`certificado`
(eBox creará uno automáticamente usando el nombre del servidor
OpenVPN) y una :guilabel:`dirección de red`. Las direcciones de la red
VPN se asignan tanto al servidor como a los clientes. Si se necesita
cambiar la *dirección de red* nos deberemos asegurar que no entra en
conflicto con una red local. Además, las redes locales, es decir, las
redes conectadas directamente a los interfaces de red de la máquina,
se anunciarán automáticamente a través de la red privada.

Como vemos, el servidor OpenVPN estará escuchando en todas las
interfaces externas. Por tanto, debemos poner al menos una de nuestras
interfaces como externa vía :menuselection:`Red --> Interfaces`. En
nuestro escenario sólo se necesitan dos interfaces, una interna para
la LAN y otra externa para el lado colocado hacia Internet. Es posible
configurar nuestro servidor para escuchar en las interfaces internas,
activando la opción de *Network Address Translation* (NAT), pero de momento
la vamos a ignorar.

Si queremos que los clientes puedan conectarse entre sí usando su
dirección de VPN, debemos activar la opción :guilabel:`Permitir
conexiones entre clientes`.

El resto de opciones de configuración las podemos dejar con sus
valores por defecto.

.. image:: images/vpn/02-vpn-server.png
   :scale: 80
   :align: center

Tras crear el servidor OpenVPN, debemos habilitar el servicio y
guardar los cambios. Posteriormente, se debe comprobar en
:menuselection:`Dashboard` que un servidor OpenVPN está funcionando.

Tras ello, debemos anunciar redes, dichas redes serán accesibles por
los clientes OpenVPN autorizados. Hay que tener en cuenta que eBox anunciará
todas las redes internas automáticamente. Por supuesto, podemos añadir o
eliminar las rutas que necesitemos. En nuestro escenario,
se habrá añadido automáticamente la red local para hacer visible el cliente 3 a los
otros dos clientes.

Una vez hecho esto, es momento de configurar los clientes.  La forma
más sencilla de configurar un cliente OpenVPN es utilizando nuestros
*bundles*. Estos están disponibles en la tabla que aparece en
:menuselection:`VPN --> Servidores`, pulsando el icono de la columna
:guilabel:`Descargar bundle del cliente`. Se han creado dos *bundles*
para dos tipos de sistema operativo. Si se usa un entorno como MacOS™
o GNU/Linux, se debe elegir el sistema :guilabel:`Linux`. Al crear un
*bundle* se seleccionan aquellos certificados que se van dar al
cliente y se establece la dirección IP externa a la cual los clientes
VPN se deben conectar. Si el sistema seleccionado es Windows™, se
incluye también un instalador de OpenVPN para *Win32*. Los *bundles*
de configuración los descargará el administrador de eBox para
distribuirlos a los clientes de la manera que crea más oportuna.

.. image:: images/vpn/03-vpn-client.png
   :scale: 80
   :align: center

Un *bundle* incluye el fichero de configuración y los ficheros
necesarios para comenzar una conexión VPN. Por ejemplo, en Linux,
simplemente se descomprime el archivo y se ejecuta, dentro del
recientemente creado directorio, el siguiente comando::

   openvpn --config filename

Ahora tenemos acceso al cliente 3 desde los dos clientes remotos. Hay
que tener en cuenta que el servicio local de DNS de eBox no funciona a
través de la red privada a no ser que se configuren los clientes remotos
para que usen eBox como servidor de nombres. Es por ello que no
podremos acceder a los servicios de las máquinas de la LAN por nombre,
únicamente podremos hacerlo por dirección IP. Eso mismo ocurre con el
servicio de NetBIOS [#]_ para acceder a recursos compartidos por
Windows, para navegar en los recursos compartidos desde la VPN se
deben explícitamente permitir el tráfico de difusión del servidor
SMB/CIFS.

.. [#] Para más información sobre compartición de ficheros ir a la
       sección :ref:`filesharing-chapter-ref`

Para conectar entre sí los clientes remotos, necesitamos activar la
opción :guilabel:`Permitir conexiones cliente-a-cliente` dentro de la
configuración del servidor OpenVPN. Para comprobar que la
configuración es correcta, observar en la tabla de rutas del cliente
donde las nuevas redes anunciadas se han añadido al interfaz virtual
**tapX**.

Los usuarios conectados actualmente al servicio VPN se muestran en el
:guilabel:`Dashboard` de eBox.

.. FIXME: VPN dashboard image 

.. _vpn-example-b-ref:

Ejemplo práctico B
^^^^^^^^^^^^^^^^^^

En este ejercicio vamos a configurar un servidor de VPN. Configuraremos un
cliente en un ordenador residente en una red externa, conectaremos a la VPN y a
través de ella accederemos a una máquina residente en una red local a la que
solo tiene acceso el servidor por medio de una interfaz interna.

Para ello:

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activar el módulo :guilabel:`OpenVPN`, para ello marcar su casilla
   en la columna *Estado*.

   Efecto:
     eBox solicita permiso para realizar algunas acciones.

#. **Acción:**
   Leer las acciones que se van a realizar y otorgar permiso a eBox
   para hacerlo.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar cambios`.

#. **Acción:**
   Acceder a la interfaz de eBox, entrar en la sección
   :menuselection:`VPN --> Servidores`, pulsar sobre :guilabel:`Añadir
   nuevo`, aparecerá un formulario con los campos
   :guilabel:`Habilitado` y :guilabel:`Nombre`. Introduciremos un
   nombre para el servidor.

   Efecto:
     El nuevo servidor aparecerá en la lista de servidores.

#. **Acción:**
   Pulsar en :guilabel:`Guardar cambios` y aceptar todos los cambios.

   Efecto:
     El servidor está activo, podemos comprobar su estado en la
     sección :menuselection:`Dashboard`.

#. **Acción:**
     Para facilitar la configuración del cliente, descargar el
     *bundle* de configuración para el cliente. Para ello, pulsar en
     el icono de la columna :guilabel:`Descargar bundle de cliente` y
     rellenar el formulario de configuración. Introducir las
     siguientes opciones:

       * :guilabel:`Tipo de cliente`: seleccionar *Linux*, ya que
         es el SO del cliente.
       * :guilabel:`Certificado del cliente`: elegir  *cliente1*. Si
         no está creado este certificado, crearlo siguiendo las
         instrucciones del ejercicio anterior.
       * :guilabel:`Dirección del servidor`: aquí introducir la
         dirección por la que el cliente puede alcanzar al servidor
         VPN. En nuestro escenario coincide con la dirección de la
         interfaz externa conectada a la misma red que el ordenador
         cliente.

     Efecto:
      Al cumplimentar el formulario, bajaremos un archivo con el *bundle* para
      el cliente. Será un archivo en formato comprimido *.tar.gz*.


#. **Acción:**
     Configurar el ordenador del cliente. Para ello descomprimir
     el *bundle* en un directorio. Observar que el *bundle* contenía los
     ficheros con los certificados necesarios y un fichero de configuración con
     la extensión '.conf'. Si no han existido equivocaciones en los pasos
     anteriores ya tenemos toda la configuración necesaria y no nos queda más
     que lanzar el programa.

     Para lanzar el cliente ejecutar el siguiente
     comando dentro del directorio::

        openvpn --config  [ nombre_del_fichero.conf ]

     Efecto:
      Al lanzar el comando en la ventana de terminal se irán imprimiendo las
      acciones realizadas por el programa. Si todo es correcto, cuando la
      conexión esté lista se leerá en la pantalla
      *Initialization Sequence Completed*; en caso contrario se leerán mensajes
      de error que ayudarán a diagnosticar el problema.

#. **Acción:**
     Antes de  comprobar que existe conexión entre el cliente y el ordenador
     de la red privada, debemos estar seguros que este último tiene ruta de
     retorno al cliente VPN. Si estamos usando eBox como puerta de enlace
     por defecto, no habrá problema, en caso contrario necesitaremos añadir una
     ruta al cliente.

     Primero comprobaremos que existe la conexión con el comando **ping**,
     para ello ejecutaremos el siguiente comando::

        ping -c 3  [ dirección_ip_del_otro_ordenador ]

     Para comprobar que no sólo hay comunicación sino que podemos acceder a los
     recursos del otro ordenador, iniciar una sesión de consola remota, para
     ello usamos el siguiente comando desde el ordenador del cliente::

        ssh  [ dirección_ip_del_otro_ordenador ]

     Después de aceptar la identidad del ordenador e introducir usuario
     y contraseña, accederemos a la consola del otro ordenador.

.. _client-NAT-VPN-ref:

Cliente remoto NAT con VPN
--------------------------

Si queremos tener un servidor VPN que no sea la puerta de enlace de la
red local, es decir, la máquina no posee interfaces externos, entonces
necesitaremos activar la opción de :guilabel:`Network Address
Translation`. Como es una opción del cortafuegos, tendremos que
asegurarnos que el módulo de **cortafuegos** está activo, de lo
contrario no podremos activar esta opción. Con dicha opción, el
servidor VPN se encargará de actuar como representante de los clientes
VPN dentro de la red local. En realidad, lo será de todas las redes
anunciadas, para asegurarse que recibe los paquetes de respuesta que
posteriormente reenviará a través de la red privada a sus
clientes. Esta situación se explica mejor con el siguiente gráfico:

.. figure:: images/vpn/vpn-nat.png
   :alt: Conexión desde un cliente VPN a la LAN con VPN usando NAT
   :scale: 80

   *GRAPHIC: Conexión desde un cliente VPN a la LAN con VPN usando NAT*

Interconexión segura entre redes locales
----------------------------------------

En este escenario tenemos dos oficinas en diferentes redes que necesitan
estar conectadas a través de una red privada. Para hacerlo, usaremos
eBox en ambas como puertas de enlace. Una actuará como cliente OpenVPN
y otra como servidora. La siguiente imagen trata de aclarar la
situación:

.. figure:: images/vpn/two-offices.png
   :scale: 70
   :alt: eBox como servidor OpenVPN vs. eBox como cliente OpenVPN

   eBox como servidor OpenVPN vs. eBox como cliente OpenVPN

Nuestro objetivo es conectar al cliente 1 en la LAN 1 con el cliente 2
en la LAN 2 como si estuviesen en la misma red local. Por tanto,
debemos configurar un servidor OpenVPN como hacemos en el
:ref:`vpn-example-b-ref`.

Sin embargo, se necesita hacer dos pequeños cambios habilitando la
opción :guilabel:`Permitir túneles eBox a eBox` para intercambiar
rutas entre máquinas eBox y :guilabel:`contraseña túnel eBox a eBox`
para establecer la conexión en un entorno más seguro entre las dos
oficinas. Hay que tener en cuenta que deberemos anunciar la red LAN 1
en :guilabel:`Redes anunciadas`.

Para configurar eBox como un cliente OpenVPN, podemos hacerlo a través
de :menuselection:`VPN --> Clientes`. Debes dar un :guilabel:`nombre`
al cliente y activar el :guilabel:`servicio`. Se puede establecer la
configuración del cliente manualmente o automáticamente usando el
*bundle* dado por el servidor VPN, como hemos hecho en el
:ref:`vpn-example-b-ref`. Si no se usa el *bundle*, se tendrá que dar la
:guilabel:`dirección IP` y el par :guilabel:`protocolo-puerto` donde
estará aceptando peticiones el servidor. También será necesaria la
:guilabel:`contraseña del túnel` y los :guilabel:`certificados` usados
por el cliente. Estos certificados deberán haber sido creados por la
misma **autoridad de certificación** que use el servidor.

.. image:: images/vpn/04-vpn-eBox-client.png
   :scale: 70
   :align: center

Cuando se guardan los cambios, en el :menuselection:`Dashboard`, se puede
ver un nuevo demonio OpenVPN en la red 2 ejecutándose como cliente con
la conexión objetivo dirigida a la otra eBox dentro de la LAN 1.

.. image:: images/vpn/05-vpn-dashboard.png
   :scale: 80
   :align: center

Cuando la conexión esté completa, la máquina que tiene el papel de
servidor tendrá acceso a todas las rutas de las maquinas clientes a
través de la VPN. Sin embargo, aquellas cuyo papel sea de cliente
sólo tendrán acceso a aquellas rutas que el servidor haya anunciado
explícitamente.

Ejemplo práctico C
^^^^^^^^^^^^^^^^^^

El objetivo de este ejercicio es montar un túnel entre dos redes que usan
servidores eBox como puerta de enlace hacia una red externa, de forma que los
miembros de ambas redes se puedan conectar entre sí.

#. **Acción:**
   Acceder a la interfaz *Web* de eBox que va a tener el papel de servidor en
   el túnel. Asegurarse de que el módulo de **VPN** está activado y activarlo si
   es necesario.
   Una vez en la sección :menuselection:`VPN --> Servidores`, crear
   un nuevo servidor.
   Usar los siguientes parámetros de configuración:

      * :guilabel:`Puerto`: elegir un puerto que no esté en uso, como el 7766.
      * :guilabel:`Dirección de VPN`: introducir una dirección privada de red
        que no esté en uso en ninguna parte de nuestra infraestructura, por
        ejemplo 192.168.77.0/24.
      * Habilitar :guilabel:`Permitir túneles eBox-a-eBox`. Esta es la opción
        que indica que va a ser un servidor de túneles.
      * Introducir una :guilabel:`contraseña para túneles eBox-a-eBox`.
      * Finalmente, desde la selección de :guilabel:`Interfaces donde escuchará el
        servidor`, elegir la interfaz externa con la que podrá conectar la eBox
        cliente.

   Para concluir la configuración del servidor se deben anunciar redes
   siguiendo los mismos pasos que en ejemplos anteriores. Anunciar la red
   privada a la que se quiere que tenga acceso el cliente.
   Conviene recordar que este paso no va a ser necesario en el cliente, el
   cliente suministrará todas sus rutas automáticamente al servidor.
   Nos resta habilitar el servidor y guardar cambios.

   Efecto:
     Una vez realizados todos los pasos anteriores tendremos al servidor
     corriendo, podemos comprobar su estado en el
     :menuselection:`Dashboard`.

#. **Acción:**
   Para facilitar el proceso de configuración del cliente, obtener
   un *bundle* de configuración del cliente, descargándolo del servidor.
   Para descargarlo, acceder de nuevo a la interfaz *Web* de eBox y en la
   sección  :menuselection:`VPN --> Servidores`, pulsar en
   :guilabel:`Descargar bundle de configuración del cliente` en
   nuestro servidor. Antes de poder descargar el *bundle* se deben
   establecer algunos parámetros en el formulario de descarga:

      * :guilabel:`Tipo de cliente`: elegir *Túnel eBox a eBox*.
      * :guilabel:`Certificado del cliente`: elegir un certificado que no sea
        el del servidor ni esté en uso por ningún cliente más. Sino se
        tienen suficientes certificados, seguir los pasos de ejercicios
        anteriores para crear un certificado que pueda usar el cliente.
      * :guilabel:`Dirección del servidor`: aquí se debe introducir la
        dirección por la que el cliente pueda conectar con el servidor, en
        nuestro escenario la dirección de la interfaz externa conectada a la
        red visible tanto por el servidor como el cliente será la dirección
        adecuada.

   Una vez introducidos todos los datos pulsamos el botón de
   :guilabel:`Descargar`.

   Efecto:
     Descargamos un archivo *tar.gz* con los datos de configuración necesarios
     para el cliente.

#. **Acción:**
   Acceder a la interfaz *Web* del servidor eBox que va a tener el papel de
   cliente. Comprobar que el módulo **VPN** está activo, ir a la sección
   :menuselection:`VPN --> Clientes`. En esta sección se ve una lista
   vacía de clientes, para crear uno pulsar sobre :guilabel:`Añadir
   cliente` e introducir un *nombre* para él. Como no está configurado
   no se podrá habilitar, así que se debe volver a la lista de clientes y
   pulsar en el apartado de configuración correspondiente a nuestro
   cliente. Dado que se tiene un *bundle* de configuración de cliente,
   no se necesita rellenar las secciones a mano. Usaremos la opción
   :guilabel:`Subir bundle de configuración del cliente`, seleccionar
   el archivo obtenido en el paso anterior y pulsar sobre
   :guilabel:`Cambiar`. Una vez cargada la configuración, se puede
   retornar a la lista de clientes y habilitar nuestro cliente. Para
   habilitarlo, pulsar en el icono de :guilabel:`Editar`, que se
   encuentra en la columna de :guilabel:`Acciones`. Aparecerá un
   formulario donde podremos marcar la opción de *Habilitado*.  Ahora
   tenemos el cliente totalmente configurado y sólo nos resta guardar
   los cambios.

   Efecto:
     Una vez guardados los cambios, tendremos el cliente activo como
     podremos comprobar en el :menuselection:`Dashboard`. Si tanto la
     configuración del servidor como del cliente son correctas, el
     cliente iniciará la conexión y en un instante tendremos el túnel
     listo.

#. **Acción:**
   Ahora se comprobará que los ordenadores en las redes internas del servidor y
   del cliente pueden verse entre sí. Además de la existencia del túnel serán
   necesarios los siguientes requisitos:

     * Los ordenadores deberán conocer la ruta de retorno a la otra red
       privada. Si, como en nuestro escenario, eBox está siendo utilizado como
       puerta de enlace no habrá necesidad de introducir rutas adicionales.
     * El cortafuegos deberá permitir conexiones entre las rutas para los
       servicios que utilicemos.

   Una vez comprobados estos requisitos podremos pasar a comprobar la conexión,
   para ello entraremos en uno de los ordenadores de la red privada del
   servidor VPN y haremos las siguientes comprobaciones:

      * **Ping** a un ordenador en la red del cliente VPN.
      * Tratar de iniciar una sesión SSH en un ordenador de la red del cliente
        VPN.

   Terminadas estas comprobaciones, las repetiremos desde un ordenador
   de la red del cliente VPN, eligiendo como objetivo un ordenador
   residente en la red del servidor VPN.

.. include:: vpn-exercises.rst
