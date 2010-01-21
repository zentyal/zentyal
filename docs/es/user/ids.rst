.. _ids-ref:

Sistema de Detección de Intrusos (IDS)
**************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>

Un **Sistema de Detección de Intrusos (IDS)** es una aplicación diseñada para evitar
accesos no deseados a nuestras máquinas, principalmente ataques provenientes de
*Internet*.

Las dos funciones principales de un IDS es **detectar** los posibles ataques o
intrusiones, lo cual se realiza mediante un conjunto de reglas que se aplican
sobre los paquetes del tráfico entrante. Además de **registrar** todos los eventos
sospechosos, añadiendo información útil (como puede ser la dirección IP de origen
del ataque), a una base de datos o fichero de registro; algunos IDS combinados con
el cortafuegos también son capaces de **bloquear** los intentos de intrusión.

Existen distintos tipos de IDS, el más común de ellos es el Sistema de Detección
de Intrusos de Red (NIDS), se encarga de examinar todo el tráfico de una red
local. Uno de los NIDS más populares es Snort [#]_, que es la
herramienta que integra eBox para realizar dicha tarea.

.. [#] **Snort**: *A free lightweight network intrusion detection
       system for UNIX and Windows* http://www.snort.org

Configuración de un IDS con eBox
================================

La configuración del Sistema de Detección de Intrusos en eBox es muy sencilla.
Solamente necesitamos activar o desactivar una serie de elementos. En primer lugar,
tendremos que especificar en qué interfaces de red queremos habilitar la escucha
del IDS. Tras ello, podemos seleccionar distintos conjuntos de reglas a aplicar
sobre los paquetes capturados, con el objetivo de disparar alertas en caso de
resultados positivos.

A ambas opciones de configuración se accede a través del menú
:menuselection:`IDS`. En la pestaña :guilabel:`Interfaces` aparecerá
una tabla con la lista de todas las interfaces de red que tengamos
configuradas. Por defecto, todas ellas se encuentran deshabilitadas
debido al incremento en la latencia de red y consumo de CPU que genera
la inspección de tráfico. Para habilitar alguna de ellas podemos
pulsar en el icono del lápiz, marcar la casilla :guilabel:`Habilitada`
y pulsar el botón :guilabel:`Cambiar`.

.. image:: images/ids/ids-01-interfaces.png
   :scale: 80
   :align: center

En la pestaña :guilabel:`Reglas` tenemos una tabla en la que se encuentran
precargados todos los conjuntos de reglas de *Snort* instaladas en nuestro sistema
(ficheros bajo el directorio `/etc/snort/rules`). Por defecto, se encuentra
habilitado un conjunto típico de reglas. Podemos ahorrar tiempo de CPU
desactivando aquellas que no nos interesen, por ejemplo, las
relativas a servicios que no existen en nuestra red. Si tenemos recursos hardware
de sobra podemos también activar otras reglas adicionales que nos puedan interesar.
El procedimiento para activar o desactivar una regla es el mismo que para las
interfaces.

.. image:: images/ids/ids-02-rules.png
   :scale: 80
   :align: center

Alertas del IDS
===============

Con lo que hemos visto hasta ahora podemos tener funcionando el módulo IDS, pero
su única utilidad sería que podríamos observar manualmente las distintas alertas
en el fichero `/var/log/snort/alert`. Como vamos a ver, gracias al sistema de
registros y eventos de eBox podemos hacer que esta tarea sea más sencilla y
eficiente.

El módulo IDS se encuentra integrado con el módulo de registros de eBox, así que
si este último se encuentra habilitado, podremos consultar las distintas alertas
del IDS mediante el procedimiento habitual. Así mismo, podemos configurar un evento
para que cualquiera de estas alertas sea notificada al administrador del sistema
por alguno de los distintos medios disponibles.

Para más información al respecto, consultar el capítulo :ref:`logs-ref`.

Ejemplo práctico
^^^^^^^^^^^^^^^^

Habilitar módulo **IDS** y lanzar un "ataque" basado en el escaneo de
puertos contra la máquina eBox.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activar el módulo :guilabel:`IDS`, para ello marcar su casilla en la
   columna :guilabel:`Estado`. Nos informa de que se modificará la
   configuración de Snort. Permitir la operación pulsando el botón
   :guilabel:`Aceptar`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Del mismo modo, activar el módulo :guilabel:`registros`, en caso de que
   no se encontrase activado previamente.

   Efecto:
     Cuando el IDS entre en funcionamiento podrá registrar sus alertas.

#. **Acción:**
   Acceder al menú :menuselection:`IDS` y en la pestaña
   :guilabel:`Interfaces` activar una interfaz que sea alcanzable desde la
   máquina en la que lanzaremos el ataque.

   Efecto:
     El cambio se ha guardado temporalmente pero no será efectivo hasta que
     se guarden los cambios.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     A partir de ahora el IDS se encuentra analizando el tráfico de la
     interfaz seleccionada.

#. **Acción:**
   Instalar el paquete **nmap** en otra máquina mediante el comando
   `aptitude install nmap`.

   Efecto:
     La herramienta **nmap** se encuentra instalada en el sistema.

#. **Acción:**
   Desde la misma máquina ejecutar el comando `nmap` pasándole como único
   argumento de línea de comandos la dirección IP de la interfaz de eBox
   seleccionada anteriormente.

   Efecto:
     Se efectuarán intentos de conexión a distintos puertos de la máquina
     eBox. Se puede interrumpir el proceso pulsando :kbd:`Ctrl-c`.

#. **Acción:**
   Acceder a :menuselection:`Registros --> Consulta Registros` y seleccionar
   :menuselection:`Informe completo` para el dominio :guilabel:`IDS`.

   Efecto:
     Aparecen en la tabla entradas relativas al ataque que acabamos de
     efectuar.

.. include:: ids-exercises.rst
