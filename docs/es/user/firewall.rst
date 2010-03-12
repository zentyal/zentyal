.. _firewall-ref:

Cortafuegos
***********

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Isaac Clerencia <iclerencia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Víctor Jímenez <vjimenez@warp.es>,
                   Javier Uruen <juruen@ebox-platform.com>,

Para ver la aplicación de los objetos y servicios de red, vamos a configurar un
cortafuegos. Un **cortafuegos** es un sistema que refuerza las políticas de control
de acceso entre redes. En nuestro caso, vamos a tener una máquina dedicada a
protección de nuestra red interna y eBox de ataques procedentes de la red exterior.

Un cortafuegos permite definir al usuario una serie de políticas de acceso,
por ejemplo, cuáles son las máquinas a las que se puede conectar
o las que pueden recibir información y el tipo de la misma. Para ello, utiliza
reglas que pueden filtrar el tráfico dependiendo de determinados parámetros,
por ejemplo protocolo, dirección origen o destino y puertos utilizados.

Técnicamente, la mejor solución es disponer de un computador con dos o más
tarjetas de red que aislen las diferentes redes (o segmentos de ellas)
conectadas, de manera que el software cortafuegos se encargue de conectar los
paquetes de las redes y determinar cuáles pueden pasar o no y a qué red lo
harán. Al configurar nuestra máquina como cortafuegos y encaminador podremos
enlazar los paquetes de tránsito entre redes de manera más segura.

El cortafuegos en GNU/Linux: Netfilter
======================================

A partir del núcleo Linux 2.4, se proporciona un subsistema de
filtrado denominado **Netfilter** que proporciona características de
filtrado de paquetes y de traducción de redes NAT [#]_. La interfaz
del comando **iptables** permite realizar las diferentes tareas de
configuración de las reglas que afectan al sistema de filtrado (tabla
*filter*), reglas que afectan a la traducción de los paquetes con NAT
(tabla *nat*) o reglas para especificar algunas opciones de control y
manipulación de paquetes (tabla *mangle*). Su manejo es muy flexible y
ortogonal pero añade mucha complejidad y tiene una curva de
aprendizaje alta.

.. [#] *Network Address Translation* (**NAT**): Es el proceso de reescribir
       la fuente o destino de un paquete IP mientras pasan por un encaminador
       o cortafuegos. Su uso principal es permitir a varias máquinas de una
       red privada acceder a Internet con una única IP pública.

Modelo de seguridad de eBox
===========================

El modelo de seguridad de eBox se basa en intentar proporcionar la máxima
seguridad posible por defecto, intentando a su vez minimizar el esfuerzo de
configuración de un administrador cuando añade nuevos servicios.

Cuando eBox actúa de cortafuegos normalmente se instala entre la red
local y el *router* que conecta esa red con otra red, normalmente
Internet. Los interfaces de red que conectan la máquina con la red
externa (el *router*) deben marcarse como tales. Esto permite al módulo
**Cortafuegos** establecer unas políticas de filtrado por defecto.

.. figure:: images/firewall/filter-combo.png
   :alt: Gráfico: Red interna - Reglas de filtrado - Red externa
   :scale: 70

   Red interna - Reglas de filtrado - Red externa

La política para las interfaces externas es denegar todo intento de
nueva conexión a eBox. Para las interfaces internas se deniegan todos
los intentos de conexión, excepto los que se realizan a servicios
internos definidos en el módulo **Servicios**, que son aceptadas por
defecto.

Además eBox configura el cortafuegos automáticamente de tal manera que hace
**NAT** para los paquetes que provengan de una interfaz interna y salgan por una
externa. Si no se desea esta funcionalidad, puede ser desactivada mediante
la variable **nat_enabled** en el fichero de configuración del módulo
cortafuegos en `/etc/ebox/80firewall.conf`.

Configuración de un cortafuegos con eBox
----------------------------------------

Para facilitar el manejo de **iptables** en tareas de filtrado se usa
el interfaz de eBox en :menuselection:`Cortafuegos --> Filtrado de
paquetes`.

Si eBox actúa como puerta de enlace, se pueden establecer reglas de
filtrado que se encargarán de determinar si el tráfico de un
servicio local o remoto debe ser aceptado o no. Hay cinco tipos de
tráfico de red que pueden controlarse con las reglas de filtrado:

 * Tráfico de redes internas a eBox (ejemplo: permitir
   acceso SSH desde algunas máquinas).
 * Tráfico entre redes internas y de redes internas a
   Internet (ejemplo: prohibir el acceso a Internet desde determinada
   red interna).
 * Tráfico de eBox a redes externas (ejemplo: permitir
   descargar ficheros por FTP desde la propia máquina con eBox).
 * Tráfico de redes externas a eBox (ejemplo: permitir que
   el servidor de Jabber se utilice desde Internet).
 * Tráfico de redes externas a redes internas (ejemplo:
   permitir acceder a un servidor *Web* interno desde Internet).

Hay que tener en cuenta que los dos últimos tipos de reglas pueden ser
un compromiso para la seguridad de eBox y la red, por lo que deben
utilizarse con sumo cuidado. Se pueden ver los tipos de filtrado en el
siguiente gráfico:

.. figure:: images/firewall/firewall-schema.png
   :alt: Tipos de reglas de filtrado
   :scale: 80

   Tipos de reglas de filtrado

eBox provee una forma sencilla de controlar el acceso a sus servicios y los
del exterior desde una interfaz interna (donde se encuentra la *Intranet*) e
Internet. Su configuración habitual se realiza por objeto. Así podemos
determinar cómo un objeto de red puede acceder a cada uno de los servicios de
eBox. Por ejemplo, podríamos denegar el acceso al servicio de DNS a determinada
subred. Además se manejan las reglas de acceso a Internet, por ejemplo, para
configurar el acceso a Internet se debe habilitar la salida como cliente a los
puertos 80 y 443 del protocolo TCP a cualquier dirección.

.. figure:: images/firewall/02-firewall.png
   :alt: Lista de reglas de filtrado de paquetes desde las redes
         internas a eBox

   Lista de reglas de filtrado de paquetes desde las redes internas a eBox

Cada regla tiene un :guilabel:`origen` y :guilabel:`destino` que es
dependiente del tipo de filtrado que se realiza. Por ejemplo, las
reglas de filtrado para salida de eBox sólo hace falta fijar el
destinatario ya que el origen siempre es eBox. Se puede usar un
:guilabel:`servicio` concreto o su :guilabel:`inverso` para, por
ejemplo, denegar todo el tráfico de salida excepto el de
*SSH* [#]_. Adicionalmente, se le puede dar una :guilabel:`descripción` para
facilitar la gestión de las reglas. Finalmente, cada regla tiene una
:guilabel:`decisión` que tomar, existen tres tipos:

.. [#] SSH: *Secure Shell* permite la comunicación segura entre dos
       máquinas usando principalmente como consola remota

* Aceptar la conexión.
* Denegar la conexión ignorando los paquetes entrantes y haciendo
  suponer al origen que no se ha podido establecer la conexión.
* Denegar la conexión y además registrarla. De esta manera, a través
  de :menuselection:`Registros -> Consulta registros` del
  :guilabel:`Cortafuegos` podemos ver si una regla está funcionando
  correctamente.

Redirecciones de puertos
------------------------

Las redirecciones de puertos (NAT de destino) se configuran desde
:menuselection:`Cortafuegos --> Redirecciones de puertos` donde se
puede hacer que todo el tráfico dirigido a un puerto externo (o rango
de puertos), se direccione a una máquina que está escuchando en un
puerto determinado haciendo la traducción de la dirección destino.

Para configurar una redirección hay que establecer la
:guilabel:`interfaz` donde se va a hacer la traducción, el
:guilabel:`destino original` (puede ser eBox, una dirección IP o un
objeto), el :guilabel:`puerto de destino original` (puede ser
*cualquiera*, un rango de puertos o un único puerto), el
:guilabel:`protocolo`, la :guilabel:`origen` desde donde se iniciará
la conexión (en una configuración usual su valor será *cualquiera*),
la :guilabel:`IP destino` y, finalmente, el :guilabel:`puerto` donde
la máquina destino recibirá las peticiones, que puede ser el mismo que
el original o no. Existe también un campo opcional llamado
:guilabel:`descripción` que es útil para añadir un comentario que
describa el propósito de la regla.

.. image:: images/firewall/07-redirection.png
   :scale: 70
   :align: center
   :alt: Editando una redirección

Según el ejemplo, todas las conexiones que vayan a eBox a través del
interfaz *eth0* al puerto 8080/TCP se redirigirán al puerto 80/TCP de
la máquina con dirección IP *10.10.10.10*.

Ejemplo práctico
----------------
Usar el programa **netcat** para crear un servidor sencillo que escuche
en el puerto 6970 en la máquina eBox. Añadir un servicio y una regla
de cortafuegos para que una máquina interna pueda acceder al servicio.

Para ello:

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y activar el módulo
   **Cortafuegos**, para ello marcar su casilla en la columna
   :guilabel:`Estado`.

   Efecto:
     eBox solicita permiso para realizar algunas acciones.

#. **Acción:**
   Leer las acciones que se van a realizar y otorgar permiso a eBox
   para hacerlo.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**

.. manual

   Crear un servicio interno como en el :ref:`serv-exer-ref` de la
   sección :ref:`abs-ref` a través de :menuselection:`Servicios` con
   nombre **netcat** con :guilabel:`puerto
   destino` 6970. Seguidamente, ir a :menuselection:`Cortafuegos -->
   Filtrado de paquetes` en :guilabel:`Reglas de filtrado desde las
   redes internas a eBox` añadir la regla con, al menos, los
   siguientes campos:

.. endmanual

.. web

   Crear un servicio interno a través de :menuselection:`Servicios` con
   nombre **netcat** con :guilabel:`puerto
   destino` 6970. Seguidamente, ir a :menuselection:`Cortafuegos -->
   Filtrado de paquetes` en :guilabel:`Reglas de filtrado desde las
   redes internas a eBox` añadir la regla con, al menos, los
   siguientes campos:

.. endweb

   - :guilabel:`Decisión` : *ACEPTAR*
   - :guilabel:`Fuente` : *Cualquiera*
   - :guilabel:`Servicio` : *netcat*. Creado en esta acción.

   Una vez hecho esto. :guilabel:`Guardar cambios` para confirmar la
   configuración.

   Efecto:
     El nuevo servicio **netcat** se ha creado con una regla para las
     redes internas que permiten conectarse al mismo.

#. **Acción:**
   Lanzar desde la consola de eBox el siguiente comando::

     nc -l -p 6970

#. **Acción:**
   Desde la máquina cliente comprobar que hay acceso a dicho
   servicio usando el comando **nc**::

     nc <ip_eBox> 6970

   Efecto
     Puedes enviar datos que serán visto en la terminal donde hayas
     lanzado **netcat** en eBox.

.. include:: firewall-exercises.rst
