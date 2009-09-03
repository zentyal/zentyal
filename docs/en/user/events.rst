Incidencias (eventos y alertas)
*******************************

Aunque la posibilidad de hacer consultas personalizadas a los registros, o
la visualización de los resúmenes son opciones muy útiles. Se
complementan mejor todavía con las posibilidades de monitorización de
**eventos** a través de la notificación.

Disponemos de los siguientes mecanismos emisores para la notificación de
incidencias:

- Correo [#]_
- Jabber
- Registro
- RSS

.. [#] Teniendo instalado y configuración el módulo de **correo**
   (:ref:`mail-service-ref`).

Antes de activar los eventos debemos asegurarnos de que el módulo se
encuentra habilitado. Para habilitarlo, como de costumbre, debemos ir
a :menuselection:`Estado del módulo` y seleccionar la casilla
:guilabel:`eventos`.

A diferencia de los registros, que salvo en el caso del **cortafuegos**, se
encuentran activados por defecto, para los eventos tendremos que activar
explícitamente aquellos que nos interesen.

Para activar cualquiera de ellos accederemos al menú
:menuselection:`Eventos --> Configurar eventos`. Podemos editar el
estado de cada uno mediante el icono del lápiz. Para ello marcaremos
la casilla :guilabel:`Habilitado` y pulsaremos el botón
:guilabel:`Cambiar`.

.. figure:: images/events/05-config-events.png
   :scale: 80
   :alt: Configurar eventos

   Pantalla de configurar eventos

Además, algunos eventos como el observador de registros o el observador de
espacio restante en disco tienen sus propios parámetros de configuración.

La configuración para el observador de espacio en disco libre es sencilla. Sólo
debemos especificar el porcentaje mínimo de espacio libre con el que
queremos ser notificados (cuando sea menor de ese valor).

En el caso del observador de registros, podemos elegir en primer lugar qué
dominios de registro queremos observar. Después, por cada uno de ellos,
podemos añadir reglas de filtrado específicas dependientes del dominio. Por
ejemplo: peticiones denegadas en el proxy HTTP, concesiones DHCP a una
determinada IP, trabajos de cola de impresión cancelados, etc. La
creación de alertas para monitorizar también se puede hacer mediante
el botón :guilabel:`Guardar como evento` a través de
:menuselection:`Registros --> Consultar registros --> Informe completo`.

.. figure:: images/events/06-config-log-observers.png
   :alt: Configurar observadores de registros

   Pantalla de configurar observadores de registros

Respecto a la selección de medios para la notificación de los eventos,
podemos seleccionar los emisores que deseemos en la pestaña
:menuselection:`Configurar emisores`.

.. figure:: images/events/07-config-dispatchers.png
   :alt: Configurar emisores

   Pantalla de configurar emisores

De idéntica forma a la activación de eventos, debemos editarlos y
seleccionar la casilla :guilabel:`Habilitado`. Excepto en el caso del
fichero de registro (que escribirá implícitamente los eventos
recibidos al fichero */var/log/ebox/ebox.log*), el resto de emisores
requieren una configuración adicional que detallamos a continuación:

Correo:
 Debemos especificar la dirección de correo destino (típicamente la
 del administrador de eBox), además podemos personalizar el asunto de los
 mensajes.

Jabber:
 Debemos especificar el nombre y puerto del servidor Jabber, el
 nombre de usuario y contraseña del usuario que nos notificará los eventos,
 y la cuenta Jabber del administrador que recibirá dichas notificaciones.

RSS:
 Nos permite seleccionar una política de lectores permitidos, así como
 el enlace del canal. Podemos hacer que el canal sea público, que no sea
 accesible para nadie, o autorizar sólo a una dirección IP u objeto
 determinado.

.. _event-exercise-ref:

Ejemplo práctico
----------------

Usar el módulo **eventos** para hacer aparecer el mensaje *"eBox is up
and running"* en el fichero ``/var/log/ebox/ebox.log``. Dicho mensaje
se generará cada vez que se reinicie el módulo de **eventos**.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activar el módulo :guilabel:`eventos`, para ello marcar su casilla en la
   columna :guilabel:`Estado`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Acceder al menú :menuselection:`Eventos` y a la pestaña
   :menuselection:`Configurar eventos`. Pulsar el icono del lápiz
   sobre la fila :guilabel:`Estado`. Marcar la casilla
   :guilabel:`Habilitado` y pulsar el botón :guilabel:`Cambiar`.

   Efecto:
     Veremos que en la tabla de eventos aparece como habilitado el evento de
     Estado.

#. **Acción:**
   Acceder a la pestaña :menuselection:`Configurar emisores`.
   Pulsar el icono del lápiz sobre la fila :guilabel:`Registro`.
   Marcar la casilla :guilabel:`Habilitado` y pulsar el botón
   :guilabel:`Cambiar`.

   Efecto:
     Veremos que en la tabla de emisores aparece como habilitado el emisor de
     Registro.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     En el fichero de registro `/var/log/ebox/ebox.log` aparecerá un evento
     con el mensaje *'eBox is up and running'*.

#. **Acción:**
   Desde la consola de la máquina eBox, ejecutar el comando
   `sudo /etc/init.d/ebox events restart`.

   Efecto:
     En el fichero de registro `/var/log/ebox/ebox.log` volverá a aparecer
     un nuevo evento con el mensaje *'eBox is up and running'*.

.. include:: events-exercises.rst
