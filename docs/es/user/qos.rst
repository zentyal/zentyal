.. _qos-ref:

Moldeado de tráfico
*******************

.. sectionauthor:: Isaac Clerencia <iclerencia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>

Calidad de servicio (QoS)
=========================

La **calidad de servicio** (*Quality of Service*, QoS) en redes de
computadores se refiere a los mecanismos de control en la reserva de
recursos que pueden dar diferente prioridad a usuarios o flujos de
datos diferentes, o garantizar un cierto nivel de rendimiento de
acuerdo con las restricciones impuestas por la
aplicación. Restricciones como el retraso en la entrega, la tasa de
*bit*, la probabilidad de pérdida de paquetes o la variación de
retraso por paquete [#]_ pueden estar fijadas por diversas
aplicaciones de flujo de datos multimedia como voz o
TV sobre IP. Estos mecanismos sólo aplican cuando los recursos son
limitados (redes inalámbricas celulares) o cuando hay congestión en
la red, en caso contrario no se debería aplicarse dichos mecanismos.

.. [#] *jitter* o *Packet Delay Variation* (PDV) es la diferencia en
       el retraso entre el emisor y el receptor entre los paquetes
       seleccionados de un flujo.

Existen diversas técnicas para dar calidad de servicio:

Reserva de recursos de red:
  Usando el protocolo *Resource reSerVation Protocol* (RSVP) para
  pedir y reservar espacio en los encaminadores. Sin embargo, esta
  opción se ha relegado ya que no escala bien en el crecimiento de
  Internet.

Uso de servicios diferenciados (*DiffServ*):
  Mediante el marcado de paquetes dependiendo el servicio al que
  sirven. Dependiendo de las marcas, los encaminadores usarán diversas
  técnicas de encolamiento para adaptarse a los requisitos de las
  aplicaciones. Esta técnica está actualmente aceptada.

Como añadido a estos sistemas, existen mecanismos de *gestión de ancho
de banda* para mejorar la calidad de servicio basada en el **moldeado
de tráfico**, **algoritmos de scheduling** o **evitación de la
congestión**.

Para el moldeado de tráfico existen básicamente dos algoritmos:

*Token bucket*:
  Dicta cuando el tráfico puede transmitirse, basado en la presencia
  de *tokens* en el *bucket* (sitio virtual donde almacenar
  *tokens*). Cada *token* es una unidad de *Bytes* determinada, así
  cada vez que se envían datos, se consumen *tokens*, cuando no hay
  *tokens* no es posible transmitir datos. Se proveen *tokens*
  periódicamente a cada uno de los *buckets*. Con esta técnica se
  permite el envío de datos en períodos de alta demanda [#]_.

*Leaky bucket*:
  Se basa en la presencia de un *bucket* con un agujero. Entran
  paquetes en el *bucket* hasta que este se llena, momento en el que
  se descartan. La salida de paquetes se hace a una tasa continua y
  estable a través de dicho agujero.

.. [#] Término conocido como *burst*.

Configuración de la calidad de servicio en eBox
===============================================

eBox utiliza las capacidades del núcleo de Linux [#]_ para hacer
moldeado de tráfico usando *token bucket* que permite una tasa
garantizada, limitada y una prioridad a determinados tipos de flujos
de datos (protocolo y puerto) a través del menú
:menuselection:`Moldeado de tráfico --> Reglas`.

.. [#] Linux Advanced Routing & Traffic Control http://lartc.org

Para poder realizar moldeado de tráfico es necesario disponer de al
menos una interfaz interna y una interfaz externa. También debe
existir un *router*. Además debemos configurar las tasas de subida y
bajada de los *routers* en :menuselection:`Moldeado de tráfico -->
Tasas de Interfaz`, estableciendo el ancho de banda que nos
proporciona cada *router* que está conectado a una interfaz externa.
Las reglas de moldeado son específicas para cada interfaz y pueden
asignarse a las interfaces externas con ancho de banda asignado y a
todas las interfaces internas.

.. FIXME: New shot with interface rates page

Si se moldea la interfaz externa, entonces se estará limitando el
tráfico de salida de eBox hacia Internet En cambio, si se moldea la
interfaz interna, entonces se estará limitando la salida de eBox hacia
sus redes internas.  El límite máximo de tasa de salida y entrada
viene dado por la configuración en :menuselection:`Moldeado de tráfico
--> Tasas de Interfaz`.  Como se puede observar, no se puede moldear
el tráfico entrante en sí, eso es debido a que el tráfico proveniente
de la red no es predecible y controlable de casi ninguna
forma. Existen técnicas específicas a diversos protocolos para tratar
de controlar el tráfico entrante a eBox, como por ejemplo, TCP con el
ajuste artificial del tamaño de ventana de flujo de la conexión TCP o
controlando la tasa de confirmaciones (*ACK*) devueltas al emisor.

Para cada interfaz se pueden añadir reglas para dar
:guilabel:`prioridad` (0: máxima prioridad, 7: mínima prioridad),
:guilabel:`tasa garantizada` o :guilabel:`tasa limitada`. Esas reglas
se aplicarán al tráfico determinado por el :guilabel:`servicio`,
:guilabel:`origen` y :guilabel:`destino` del flujo.

.. figure:: images/qos/03-trafficshaping.png
   :scale: 80
   :align: center
   :alt: Reglas de moldeado de tráfico

   Reglas de moldeado de tráfico

Ejemplo práctico
^^^^^^^^^^^^^^^^

Crear una regla para moldear el tráfico de bajada HTTP y limitarlo a 20KB/s.
Comprobar su funcionamiento.

#. **Acción:**
   Añadir un *router*  a través de :menuselection:`Red --> Routers` a
   tu interfaz de red externo.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`. La lista de puertas de
     enlace contiene un único router.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios.

#. **Acción:**
   Acceder de nuevo a la interfaz de eBox y añadir en :menuselection:`Servicios`
   un servicio llamado HTTP con protocolo TCP, tipo externo y puerto de destino
   simple 80.

   Efecto:
     eBox muestra una lista con los servicios en la que aparece nuestro nuevo
     servicio HTTP.

#. **Acción:**
   Ir a la entrada :menuselection:`Moldeado de tráfico --> Reglas`. Seleccionar la
   interfaz interna en la lista de interfaces y pulsar en
   :guilabel:`Añadir nuevo` para añadir una nueva regla con los siguientes
   datos:

   :Habilitada:       Sí
   :Servicio:         Servicio basado en puerto / HTTP
   :Origen:           cualquiera
   :Destino:          cualquiera
   :Prioridad:        7
   :Tasa garantizada: 0 Kb/s
   :Tasa limitada:    160 Kb/s

   Pulsar el botón :guilabel:`Añadir`.

   Efecto:
     eBox muestra una tabla con la nueva regla de moldeado de tráfico.

#. **Acción:**
   Comenzar a descargar desde una máquina de tu **LAN** (distinta de
   eBox) usando el comando **wget** un fichero grande accesible desde
   Internet (por ejemplo, una imagen ISO de Ubuntu).

   Efecto:
     La velocidad de descarga de la imagen no supera los 20KB/s (160 Kbits/s).

.. include:: qos-exercises.rst
