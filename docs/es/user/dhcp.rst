.. _dhcp-ref:

Servicio de configuración de red (DHCP)
***************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Isaac Clerencia <iclerencia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Víctor Jímenez <vjimenez@warp.es>,
                   Jorge Salamero <jsalamero@ebox-platform.com>,
                   Javier Uruen <juruen@ebox-platform.com>,

Como hemos comentado, **DHCP** (*Dynamic Host Configuration Protocol*)
es un protocolo que permite a un dispositivo pedir y obtener una
dirección IP desde un servidor que tiene una lista de direcciones
disponibles para asignar.

El servicio DHCP [#]_ se usa también para obtener otros muchos
parámetros tales como la *puerta de enlace por defecto*, la *máscara
de red*, las *direcciones IP de los servidores de nombres* o el
*dominio de búsqueda* entre otros. De esta manera, se facilita el
acceso a la red sin la necesidad de una configuración manual por parte
del cliente.

.. [#] eBox usa "*ISC DHCP Software*" (https://www.isc.org/software/dhcp)
       para configurar el servicio de DHCP

Cuando un cliente DHCP se conecta a la red envía una petición de
difusión (*broadcast*). El servidor DHCP responde a esa petición
con una dirección IP, su tiempo de concesión y los otros
parámetros explicados previamente. La petición suele suceder durante
el período de arranque del cliente y debe completarse antes de seguir
con el arranque del resto de servicios de red.

Existen dos métodos de asignación de direcciones:

Manual:
  La asignación se hace a partir de una tabla de correspondencia entre
  direcciones físicas (*MAC*) y direcciones IP. El administrador de la red se
  encarga del mantenimiento de esta tabla.
Dinámica:
  El administrador de la red asigna un rango de direcciones IP por un proceso
  de petición y concesión que usa el concepto de alquiler con un período
  controlado de tiempo en el que la IP concedida es válida. El servidor guarda
  una tabla con las asignaciones anteriores para intentar volver a asignar la
  misma IP a un cliente en sucesivas peticiones.

Configuración de un servidor DHCP con eBox
==========================================

Para configurar el servicio DHCP con eBox, se necesita al menos una
interfaz configurada estáticamente. Una vez la tenemos, vamos al menú
:menuselection:`DHCP` donde se configurará el servidor DHCP.

.. figure:: images/dhcp/01-dhcp.png
   :alt: Vista general de configuración del servicio DHCP

   Vista general de configuración del servicio DHCP

Como hemos dicho, se pueden enviar algunos parámetros de la red junto con la
dirección IP, estos parámetros se pueden configurar en la pestaña de
:menuselection:`Opciones comunes`.

Puerta de enlace por defecto:
  Es la puerta de enlace que va a emplear el cliente si no conoce otra
  ruta por la que enviar el paquete a su destino. Su valor puede ser
  :guilabel:`eBox`, una puerta de enlace ya configurada en el apartado
  :menuselection:`Red --> Routers` o una :guilabel:`dirección IP
  personalizada`.

Dominio de búsqueda:
  En una red cuyas máquinas estuvieran nombradas siguiendo la forma
  *<máquina>.sub.dominio.com*, se podría configurar el dominio de búsqueda
  como "sub.dominio.com". De esta forma, cuando se intente resolver un
  nombre de dominio sin éxito, se intentará de nuevo añadiéndole el
  dominio de búsqueda al final o partes de ese dominio.

  Por ejemplo, si *smtp* no se puede resolver como dominio, se
  intentará resolver *smtp.dominio.com* en la máquina cliente.

  Podemos escribir el dominio de búsqueda, o podemos seleccionar uno
  que se haya configurado en el servicio de DNS.

Servidor de nombres primario:
  Se trata de aquel servidor DNS [#]_ con el que contactará el cliente
  en primer lugar cuando tenga que resolver un nombre o traducir una
  dirección IP a un nombre. Su valor puede ser :guilabel:`eBox DNS
  local` (si queremos que se consulte el propio servidor DNS de eBox,
  hay que tener en cuenta que el módulo **dns** debe estar habilitado)
  o una dirección IP de otro servidor DNS.

.. [#] Ir a la sección :ref:`dns-chapter-ref` para tener más detalles
       sobre este servicio.

Servidor de nombres secundario:
  Servidor DNS con el que contactará el cliente si el primario no está
  disponible. Su valor debe ser una dirección IP de un servidor DNS.

Servidor NTP:
  Este es el servidor **NTP** (*Network Transport Protocol*) [#]_ que
  el cliente usará cuando quiera sincronizar su reloj usando la
  red. Su valor puede ser ninguno, :guilabel:`eBox NTP local` (hay que
  tener en cuenta que el módulo **ntp** debe estar habilitado) o un
  servidor NTP :guilabel:`personalizado`.

.. [#] Comprobar la sección :ref:`ntp-chapter-ref` para obtener
       detalles sobre el servicio de sincronización de hora

Servidor WINS:
  Este es el servidor **WINS** (*Windows Internet Name Service*) [#]_
  que el cliente usará para resolver nombres NetBIOS. Su valor puede
  ser ninguno, :guilabel:`eBox local` (hay que tener en cuenta que el
  módulo **samba** debe estar habilitado) o uno
  :guilabel:`personalizado`.

.. [#] WINS es una implementación para **NBNS** (*NetBIOS Name
       Service*). Para obtener más información sobre ello, ir a la
       sección :ref:`filesharing-chapter-ref`.

Debajo de las opciones comunes, se nos muestran los rangos de
direcciones que se distribuyen mediante DHCP y las direcciones
asignadas de forma manual. Para que el servicio DHCP esté activo, al
menos debe haber un rango de direcciones a distribuir o una asignación
estática. En caso contrario, el servidor DHCP **no** servirá direcciones
IP aunque esté escuchando en todas las interfaces de red.

Los rangos de direcciones y las direcciones estáticas disponibles para
asignar desde una determinada interfaz vienen determinados por la
dirección estática asignada a dicha interfaz. Cualquier dirección IP
libre de la subred correspondiente puede utilizarse en rangos o
asignaciones estáticas.

Añadir un rango en la sección :guilabel:`Rangos` se hace introduciendo
un :guilabel:`nombre` con el que identificar el rango y los valores
que se quieran asignar dentro del rango que aparece encima.

Se pueden realizar asignaciones estáticas de direcciones IP a
determinadas direcciones físicas en el apartado
:guilabel:`Asignaciones estáticas`. Una dirección asignada de este
modo no puede formar parte de ningún rango. Se puede añadir una
:guilabel:`descripción` opcional para la asignación también.

.. figure:: images/dhcp/02-dhcp-adv.png
   :alt: Aspecto de las configuración avanzada para DHCP

   Aspecto de las configuración avanzada para DHCP

La concesión dinámica de direcciones tiene un tiempo límite. Una vez
expirado este tiempo se tiene que pedir la renovación (configurable en la
pestaña :menuselection:`Opciones avanzadas`). Este tiempo varía desde 1800
segundos hasta 7200. Las asignaciones estáticas también están
limitadas en el tiempo. De hecho, desde el punto de vista del cliente,
no hay diferencia entre ellas.

Un **Cliente Ligero** es una máquina sin disco duro (y *hardware* modesto)
que arranca a través de la red, pidiendo el programa de arranque
(sistema operativo) a un servidor de clientes ligeros.

eBox permite configurar a qué servidor PXE [#]_ se debe conectar el cliente. El
servicio PXE, que se encargará de transmitir todo lo necesario para que el
cliente ligero sea capaz de arrancar su sistema, se debe configurar por
separado.

.. [#] **Preboot eXecution Environment** es un entorno para arrancar
   ordenadores usando una interfaz de red independientemente de los
   dispositivos de almacenamiento (como disco duros) o sistemas
   operativos instalados
   (http://en.wikipedia.org/wiki/Preboot_Execution_Environment)

El servidor PXE puede ser una dirección IP o un nombre, en cuyo caso será
necesario indicar la ruta de la imagen de arranque, o eBox, en cuyo
caso se puede cargar el fichero de la imagen.

.. _dynamic-dns-updates-ref:

Actualizaciones dinámicas de DNS
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

El servidor DHCP tiene la habilidad de actualizar dinámicamente el
servidor DNS [#]_. Esto es, el servidor DHCP actualizará en tiempo
real los registros **A** y **PTR** para mapear una dirección IP a un
nombre de máquina y viceversa cuando se sirva una dirección IP. La
manera que esto se hace es dependiente de la configuración del
servidor DHCP.

.. [#] El :rfc:`2136` explica como hacer actualizaciones automáticas
       en el Sistema de Nombres de Dominio (DNS).

Con eBox es posible usar la actualización dinámica de DNS integrando
los módulos de **dhcp** y **dns** de la misma máquina dentro la
pestaña :menuselection:`Opciones de DNS dinámico`. Para habilitar esta
característica, el módulo DNS debe ser habilitado también. Se debe
disponer un :guilabel:`Dominio dinámico` y un :guilabel:`Dominio
estático`, que ambos se añadirán a la configuración de DNS
automáticamente. El dominio dinámico mapea los nombres de máquinas
cuya dirección IP corresponde a una del rango y el nombre asociado
sigue este patrón:
*dhcp-<dirección-IP-ofrecida>.<dominio-dinámico>*. Con respecto al
dominio estático, el nombre de máquina seguirá este patrón:
*<nombre>.<dominio-estático>* siendo el nombre que se establece en la
tabla de :guilabel:`Asignaciones estáticas`. Hay que tener en cuenta
que una actualización desde el cliente DHCP es ignorada por eBox.

.. figure:: images/dhcp/03-dhcp-dns-updates.png
   :alt: Configuración de actualizaciones DNS dinámicas
   :scale: 70

   Configuración de actualizaciones DNS dinámicas

La actualización se hace usando un protocolo seguro [#]_ y,
actualmente, sólo el mapeo directo está soportado por eBox.

.. [#] La comunicación se realiza usando **TSIG** (*Transaction
       SIGnature*) para autenticar las peticiones de actualizaciones
       dinámicas usando una clave secreta compartida.

Ejemplo práctico
^^^^^^^^^^^^^^^^

Configurar el servicio de DHCP para que asigne un rango de 20
direcciones de red.  Comprobar desde otra máquina cliente usando
*dhclient* que funciona correctamente.

Para configurar **DHCP** debemos tener activado y configurado el módulo
**Red**. La interfaz de red sobre la cual vamos a configurar el servidor
DHCP deberá ser estática (dirección IP asignada manualmente) y el rango a
asignar deberá estar dentro de la subred determinada por la máscara de red
de esa interfaz (por ejemplo rango 10.1.2.1-10.1.2.21 en una interfaz
10.1.2.254/255.255.255.0).

#. **Acción:**
   Entrar en eBox y acceder al panel de control. Entrar en
   :menuselection:`Estado del módulo` y activar el módulo **DHCP**, para ello marcar su
   casilla en la columna :guilabel:`Estado`.

   Efecto:
     eBox solicita permiso para sobreescribir algunos ficheros.

#. **Acción:**
   Leer los cambios de cada uno de los ficheros que van a ser modificados y
   otorgar permiso a eBox para sobreescribirlos.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
     Entrar en :menuselection:`DHCP` y seleccionar la interfaz sobre la cual se configurará
     el servidor. La pasarela puede ser la propia eBox, alguna de las pasarelas
     de eBox, una dirección específica, o ninguna (sin salida a otras redes).
     Además se podrá definir el dominio de búsqueda (dominio que se añade
     a todos los nombres DNS que no se pueden resolver) y al menos un servidor DNS
     (servidor DNS primario y opcionalmente uno secundario).

     A continuación eBox nos informa del rango de direcciones
     disponibles, vamos a elegir un subconjunto de 20 direcciones y en
     :guilabel:`Añadir nueva` le damos un nombre significativo al
     rango que pasará a asignar eBox.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     Ahora eBox gestiona la configuración del servidor DHCP.

#. **Acción:**
     Desde otro equipo conectado a esa red solicitamos una IP dinámica del rango
     mediante **dhclient**::

	$ sudo dhclient eth0
	There is already a pid file /var/run/dhclient.pid with pid 9922
	killed old client process, removed PID file
	Internet Systems Consortium DHCP Client V3.1.1
	Copyright 2004-2008 Internet Systems Consortium.
	All rights reserved.
	For info, please visit http://www.isc.org/sw/dhcp/

	wmaster0: unknown hardware address type 801
	wmaster0: unknown hardware address type 801
	Listening on LPF/eth0/00:1f:3e:35:21:4f
	Sending on   LPF/eth0/00:1f:3e:35:21:4f
	Sending on   Socket/fallback
	DHCPREQUEST on wlan0 to 255.255.255.255 port 67
	DHCPACK from 10.1.2.254
	bound to 10.1.2.1 -- renewal in 1468 seconds.

#. **Acción:**
     Comprobar desde el :menuselection:`Dashboard` que la
     dirección concedida aparece en el *widget* :guilabel:`DHCP
     leases` [#]_.

.. [#] Hay que tener en cuenta que las asignaciones estáticas no
       aparecen en el *widget* del DHCP.

.. include:: dhcp-exercises.rst
