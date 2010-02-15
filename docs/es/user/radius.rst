.. _radius-ref:

RADIUS
******

.. sectionauthor:: Jorge Salamero Sanz <jsalamero@ebox-platform.com>

*RADIUS* (*Remote Authentication Dial In User Service*) es un protocolo de
red que proporciona autenticación, autorización y gestión de la tarificación,
en inglés *AAA* (*Authentication*, *Authorization* and *Accounting*) para
ordenadores que se conectan y usan una red.

El flujo de autenticación y autorización en RADIUS funciona de la
siguiente manera: el usuario o máquina envía una petición a un *NAS*
(*Network Access Server*) como podría ser un punto de acceso
inalámbrico, utilizando el protocolo de enlace pertinente para obtener
acceso a una red utilizando los credenciales de acceso. En respuesta,
el *NAS* envía un mensaje *Access Request* al servidor RADIUS
solicitando autorización para acceder a la red, incluyendo todos los
credenciales de acceso necesarios, no solo nombre de usuario y
contraseña, pero probablemente también *realm*, dirección IP, *VLAN*
asignada y tiempo máximo que podrá permanecer conectado. Esta
información se comprueba utilizando esquemas de autenticación como
*Password Authentication Protocol*
(PAP), *Challenge-Handshake Authentication Protocol* (CHAP) or
*Extensible Authentication Protocol* (EAP) [#]_ y se envía una respuesta al *NAS*:

*Access Reject*:
  Cuando se deniega el acceso al usuario.

*Access Challenge*:
  Cuando se solicita información adicional, como en TTLS donde un
  diálogo a través de un túnel establecido entre el servidor RADIUS y
  el cliente realiza una segunda autenticación.

*Access Accept*:
  Cuando se autoriza el acceso al usuario.

.. [#] Estos protocolos de autenticación están definidos en :rfc:`1334`.

Los puertos oficialmente asignados por el *IANA* son **1812/UDP** para
autenticación y **1813/UDP** para tarificación. Este protocolo no transmite
las contraseñas en texto plano entre el *NAS* y el servidor (incluso
utilizando el protocolo PAP) ya que existe una contraseña compartida que
cifra la comunicación entre ambas partes.

El servidor **FreeRADIUS** [#]_ es el elegido para el servicio de RADIUS en eBox.

.. [#] **FreeRADIUS** - *El servidor RADIUS más popular del mundo* <http://freeradius.org/>.

Configuración del servidor RADIUS con eBox
==========================================

Para configurar el servidor RADIUS en eBox, primero comprobaremos en
:menuselection:`Estado del Módulo` si :guilabel:`Usuarios y Grupos`
está habilitado, ya que RADIUS depende de él. Entonces marcaremos la
casilla :guilabel:`RADIUS` para habilitar el módulo de eBox de RADIUS.

.. figure:: images/radius/ebox-radius-01.png
   :scale: 80
   :alt: Configuración general de RADIUS

   Configuración general de RADIUS

Para configurar el servicio, accederemos a :menuselection:`RADIUS` en el menú
izquierdo. Allí podremos definir si :guilabel:`Todos los usuarios` o sólamente
los usuarios que pertenecen a uno de los grupos existentes podrán acceder al
servicio.

Todos los dispositivos *NAS* que vayan a enviar solicitudes de autenticación
a eBox deben ser especificados en :guilabel:`Clientes RADIUS`. Para cada uno
podemos definir:

:guilabel:`Habilitado`:
  Indicando si el *NAS* está habilitado o no.

:guilabel:`Cliente`:
  El nombre para este cliente, como podría ser el nombre de la máquina.

:guilabel:`Dirección IP`:
  La dirección IP o el rango de direcciones IP a las que se permite
  enviar peticiones al servidor RADIUS.

:guilabel:`Contraseña compartida`:
  Contraseña compartida entre el servidor RADIUS y el *NAS* para
  autenticar y cifrar sus comunicaciones.

Configuración del Punto de Acceso
=================================

En cada dispositivo *NAS* necesitaremos configurar la dirección de
eBox como el servidor RADIUS, el puerto, normalmente el **UDP/1812**, y
la contraseña compartida. Tanto *WPA* como *WPA2*, usando *TKIP* o
*AES* (recomendado) pueden usarse con eBox RADIUS. El modo deberá ser
*EAP*.

.. figure:: images/radius/wireless-settings.png
   :scale: 80
   :alt: Configuración del Punto de Acceso

   Configuración del Punto de Acceso

.. FIXME client configuration
