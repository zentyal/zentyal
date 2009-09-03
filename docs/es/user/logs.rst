.. _logs-ref:

Registros
*********

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>

eBox proporciona una infraestructura para que sus módulos puedan
registrar todo tipo de eventos que puedan ser útiles para el
administrador. Estos **registros** se pueden consultar a través de la
interfaz de eBox de manera común. Estos registros se almacenan en una
base de datos para hacer la consulta, los informes y las
actualizaciones de manera más sencilla y eficiente. El gestor de base
de datos que se usa es **PostgreSQL** [#]_.

.. [#] **PostgreSQL** *The world's most advanced open source database*
   http://www.postgresql.org/.

Además podemos configurar distintos manejadores para los eventos, de
forma que el administrador pueda ser notificado por distintos medios
(Correo, Jabber o RSS [#]_).

.. [#] **RSS** *Really Simple Syndication* es un formato XML usado
   principalmente para publicar obras frecuentemente actualizadas
   http://www.rssboard.org/rss-specification/.

Disponemos de registros para los siguientes servicios:

- OpenVPN (:ref:`vpn-ref`)
- SMTP Filter (:ref:`smtp-filter-ref`)
- POP3 proxy (:ref:`pop3-proxy-ref`)
- Impresoras (:ref:`printers-ref`)
- Cortafuegos (:ref:`firewall-ref`)
- DHCP (:ref:`dhcp-ref`)
- Correo (:ref:`mail-service-ref`)
- Proxy HTTP (:ref:`proxy-http-ref`)
- Ficheros compartidos (:ref:`filesharing-chapter-ref`)
- IDS (:ref:`ids-ref`)

Así mismo, podemos recibir notificaciones de los siguientes eventos:

- Valores específicos de los registros.
- Estado de salud de eBox.
- Estado de los servicios.
- Eventos del subsistema RAID por *software*
- Espacio libre en disco.
- Problemas con los *routers* de salida a *Internet*.
- Finalización de una copia completa de datos.

En primer lugar, para que funcionen los **registros**, al igual que con el resto
de módulos de eBox, debemos asegurarnos de que este se encuentre habilitado.

Para habilitarlo debemos ir a :menuselection:`Estado del módulo` y
seleccionar la casilla :guilabel:`registros`. Para obtener informes de
los registros existentes, podemos acceder a la sección
:menuselection:`Registros --> Consultar registros` del menú de eBox.

Podemos obtener un :guilabel:`Informe completo` de todos los dominios
de registro.  Además, algunos de ellos nos proporcionan un interesante
:guilabel:`Informe resumido` que nos ofrece una visión global del
funcionamiento del servicio durante un periodo de tiempo.

.. figure:: images/logs/01-logs.png
   :scale: 80
   :alt: Consulta de registros

   Pantalla de consulta de registros

En el :guilabel:`Informe completo` se nos ofrece una lista de todas
las acciones registradas para el dominio seleccionado. La información
proporcionada es dependiente de cada dominio. Por ejemplo, para el
dominio *OpenVPN* podemos consultar las conexiones a un servidor VPN
de un cliente con un certificado concreto, o por ejemplo para el
dominio *Proxy HTTP* podemos saber de un determinado cliente a qué
páginas se le ha denegado el acceso. Por tanto, podemos realizar una
consulta personalizada que nos permita filtrar tanto por intervalo
temporal como por otros distintos valores dependientes del tipo de
dominio. Dicha búsqueda podemos almacenarla en forma de evento para
que nos avise cuando ocurra alguna coincidencia. Además, si la
consulta se realiza hasta el momento actual, el resultado se irá
refrescando con nuevos datos.

.. figure:: images/logs/02-full-report.png
   :alt: Informe completo
   :scale: 50

   Pantalla de informe completo

El :guilabel:`Informe resumido` nos permite seleccionar el periodo del
informe, que puede ser de un día, una hora, una semana o un mes. La
información que obtenemos es una o varias gráficas, acompañadas de una
tabla-resumen con valores totales de distintos datos. En la imagen
podemos ver, como ejemplo, las estadísticas de peticiones y tráfico del
*proxy HTTP* al día.

.. figure:: images/logs/03-summarized-report.png
   :scale: 80
   :alt: Informe resumido

   Pantalla de informe resumido

Configuración de registros
==========================

Una vez que hemos visto como podemos consultar los registros, es
importante también saber que podemos configurarlos en la sección
:menuselection:`Registros --> Configurar los registros` del menú de
eBox.

.. figure:: images/logs/04-config-logs.png
   :scale: 80
   :alt: Configurar registros

   Pantalla de configurar registros

Los valores configurables para cada dominio instalado son:

Habilitado:
 Si esta opción no está activada no se escribirán los registros de ese
 dominio.
Purgar registros anteriores a:
 Establece el tiempo máximo que se guardarán los registros. Todos
 aquellos valores cuya antigüedad supere el periodo especificado,
 serán desechados.

Además podemos forzar la eliminación instantánea de todos los
registros anteriores a un determinado periodo. Esto lo hacemos
mediante el botón :guilabel:`Purgar` de la sección `Forzar la purga de
registros`, que nos permite seleccionar distintos intervalos
comprendidos entre una hora y 90 días.

Ejemplo práctico
^^^^^^^^^^^^^^^^
Habilitar el módulo de **registros**. Usar el
:ref:`mail-conf-exercise-ref` como referencia para generar tráfico de
correo electrónico conteniendo virus, *spam*, remitentes prohibidos y
ficheros prohibidos. Observar los resultados en
:menuselection:`Registros --> Consulta Registros --> Informe
completo`.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activa el módulo :guilabel:`registros`, para ello marcar su casilla en la
   columna :guilabel:`Estado`. Nos informa de que se creará una base de datos
   para guardar los registros. Permitir la operación pulsando el botón
   :guilabel:`Aceptar`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Acceder al menú :menuselection:`Registros --> Configurar registros`
   y comprobar que los registros para el dominio :guilabel:`Correo` se
   encuentran habilitados.

   Efecto:
     Hemos habilitado el módulo **registros** y nos hemos asegurado de tener
     activados los registros para el **correo**.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     A partir de ahora quedarán registrados todos los correos que enviemos.

#. **Acción:**
   Volver a enviar unos cuantos correos problemáticos (con *spam* o virus)
   como se hizo en el tema correspondiente.

   Efecto:
     Como ahora el módulo registros está habilitado, los correos han quedado
     registrados, a diferencia de lo que ocurrió cuando los enviamos por
     primera vez.

#. **Acción:**
   Acceder a :menuselection:`Registros --> Consulta Registros` y seleccionar
   :menuselection:`Informe completo` para el dominio :guilabel:`Correo`.

   Efecto:
     Aparece una tabla con entradas relativas a los correos que hemos
     enviado mostrando distintas informaciones de cada uno.

.. include:: logs-exercises.rst
