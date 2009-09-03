Servicio de sincronización de hora (NTP)
****************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Víctor Jiménez <vjimenez@warp.es>

El protocolo **NTP** (*Network Time Protocol*) fue diseñado para sincronizar
los relojes de las computadoras sobre una red no fiable, con latencia variable.
Este servicio escucha en el puerto 123 del protocolo UDP. Está diseñado para
resistir los efectos de la latencia variable (*jitter*).

Es uno de los protocolos más antiguos de Internet (desde antes de 1985). NTP
versión 4 puede alcanzar una exactitud de hasta 200 µs o incluso mejor si el reloj
está en la red local. Existen diferentes estratos que definen la distancia del
reloj de referencia y su asociada exactitud. Existen hasta 16 niveles. El
estrato 0 es para los relojes atómicos que no se conectan a la red sino a otro
ordenador con conexión serie RS-232 y estos son los de estrato 1. Los de
estrato 2 son los ordenadores que se conectan, ya por NTP a los de estrato
superior y normalmente son los que se ofrecen por defecto en los sistemas
operativos más conocidos como GNU/Linux, Windows, o MacOS.

Configuración de un servidor NTP con eBox
=========================================

Para configurar eBox dentro de la arquitectura NTP [#]_, en primer lugar
eBox tiene que sincronizarse con algún servidor externo de estrato
superior (normalmente 2) que se ofrecen a través de
:menuselection:`Sistema --> Fecha/hora`. Una lista de los mismos se
puede encontrar en el *pool* NTP (*pool.ntp.org*) que son una
colección dinámica de servidores NTP que voluntariamente dan un tiempo
bastante exacto a sus clientes a través de Internet.

.. [#] Proyecto del servicio público NTP
   http://support.ntp.org/bin/view/Main/WebHome.

.. image:: images/ntp/01-ntp.png
   :scale: 60
   :align: center

Una vez que eBox se haya sincronizado como cliente NTP [#]_, el propio eBox podrá
actuar también como servidor NTP, con una hora sincronizada
mundialmente.

.. [#] eBox usa como cliente NTP **ntpdate**
   http://www.ece.udel.edu/~mills/ntp/html/ntpdate.html.

Ejemplo práctico
^^^^^^^^^^^^^^^^
Habilitar el servicio NTP y sincronizar la hora de nuestra máquina
utilizando el comando **ntpdate**. Comprobar que tanto eBox como la máquina
cliente tienen la misma hora.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activa el módulo :guilabel:`ntp`, para ello marca su casilla en la
   columna :guilabel:`Estado`. Nos informa de los cambios que va a realizar
   en el sistema. Permitir la operación pulsando el botón
   :guilabel:`Aceptar`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Acceder al menú :menuselection:`Sistema --> Fecha/Hora`.
   En la sección :guilabel:`Sincronización con servidores NTP` seleccionar
   :guilabel:`Activado` y pulsar :guilabel:`Cambiar`.

   Efecto:
     Desaparece la opción de cambiar manualmente la fecha y hora y en su
     lugar aparecen campos para introducir los servidores NTP con los que se
     sincronizará.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     Nuestra máquina eBox actuará como servidor NTP.

#. **Acción:**
   Instalar el paquete **ntpdate** en nuestra máquina cliente. Ejecutar el
   comando `ntpdate <ip_de_eBox>`.

   Efecto:
     La hora de nuestra máquina habrá quedado sincronizada con la de la
     máquina eBox.

     Podemos comprobarlo ejecutando el comando **date** en ambas máquinas.
