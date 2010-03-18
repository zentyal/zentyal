Monitorización
**************

.. sectionauthor:: Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Javier Amor García <javier.amor.garcia@ebox-platform.com>,

El módulo de **monitorización** permite al administrador conocer el
estado del uso de los recursos del servidor eBox. Esta información es
esencial tanto para diagnosticar problemas como para planificar los
recursos necesarios con el objetivo de evitar problemas.

Monitorizar implica conocer ciertos valores que nos ofrece el sistema
para determinar si dichos valores son normales o están fuera del rango
común de valores, tanto en su valor inferior como superior. El
principal problema de la monitorización es la selección de aquellos
valores significativos del sistema. Para cada una de las máquinas esos
valores pueden ser diferentes. Por ejemplo, en un servidor de
ficheros el espacio libre de disco duro es importante. Sin embargo,
para un encaminador la memoria disponible y la carga son valores mucho
más significativos para conocer el estado del servicio ofrecido.
Es conveniente evitar la obtención de muchos valores sin ningún objetivo
concreto.

Es por ello que las métricas que monitoriza eBox son relativamente
limitadas. Estas son: carga del sistema, uso de CPU, uso de memoria
y uso del sistema de ficheros.

La monitorización se hace mediante gráficas que permiten hacerse
fácilmente una idea de la evolución del uso de recursos. Para acceder
a las gráficas se hace a través de la entrada
:menuselection:`Monitorización`. Ahí se muestran las gráficas de las
medidas monitorizadas. Colocando el cursor encima de algún punto de la
línea de la gráfica en el que estemos interesados podremos saber el
valor exacto para ese momento.

Podemos elegir la escala temporal de las gráficas entre una hora, un
día, un mes o un año. Para ello simplemente pulsaremos sobre la
pestaña correspondiente.

.. image:: images/monitor/monitor-tabs.png
   :scale: 80
   :align: center

Métricas
========

Carga del sistema
-----------------

La **carga del sistema** trata de medir la relación entre la demanda
de trabajo y el realizado por el computador. Esta métrica se calcula
usando el número de tareas ejecutables en la cola de ejecución y es
ofrecida por muchos sistemas operativos en forma de media de uno,
cinco y quince minutos.

La interpretación de esta métrica es la capacidad de la CPU usada en
el periodo elegido. Así, una carga de 1 significaría que esta operando
a plena capacidad. Un valor de 0.5 significaría que podría llegar a
soportar el doble de trabajo. Y siguiendo la misma proporción,
un valor de 2 se interpretaría como que le estamos exigiendo el doble del
trabajo que puede realizar.

Hay que tener en cuenta que los procesos que están interrumpidos por motivos de
lectura/escritura en almacenamiento también contribuyen a la métrica de carga.
En estos casos no se correspondería bien con el uso de la CPU, pero seguiría
siendo útil para estimar la relación entre la demanda y la capacidad de trabajo.

.. image:: images/monitor/monitor-load.png
   :scale: 70
   :align: center

Uso de la CPU
-------------

Con esta gráfica tendremos una información detallada del **uso de la
CPU**. En caso de que dispongamos de una maquina con múltiples CPUs
tendremos una gráfica para cada una de ellas.

En la gráfica se representa la cantidad de tiempo que pasa la CPU en
alguno de sus estados, ejecutando código de usuario, código del
sistema, estamos inactivo, en espera de una operación de
entrada/salida, entre otros valores. Ese tiempo no es un porcentaje
sino unidades de *scheduling* conocidos como *jiffies*. En la mayoría
de sistemas *Linux* ese valor es 100 por segundo pero no hay ninguna
limitación o posibilidad que dicho valor sea diferente.

.. image:: images/monitor/monitor-cpu-usage.png
   :scale: 70
   :align: center


Uso de la memoria
-----------------

La gráfica nos muestra el **uso de la memoria**. Se monitorizan cuatro
variables:

Memoria libre:
  Cantidad de memoria no usada
*Caché* de pagina:
  Cantidad destinada a la *caché* del sistema de ficheros
*Buffer cache*:
  Cantidad destinada a la *caché* de los procesos
Memoria usada:
  Memoria usada que no esta destinada a ninguno de las dos anteriores
  *cachés*.

.. image:: images/monitor/monitor-mem-usage.png
   :scale: 70
   :align: center

Uso del sistema de ficheros
---------------------------

Esta gráfica nos muestra el espacio usado y libre del sistema de ficheros en
cada punto de montaje.

.. image:: images/monitor/monitor-fs-usage.png
   :scale: 70
   :align: center


Temperatura
-----------

Con esta gráfica es posible leer la información disponible sobre la
temperatura del sistema en grados centígrados usando el sistema ACPI
[#]_. Para tener activada esta métrica, es necesario que existan datos
en los directorios `/sys/class/thermal` o
`/proc/acpi/thermal_zone`.

.. [#] La especificación *Advanced Configuration and Power Interface*
      (ACPI) es un estándar abierto para la configuración de
      dispositivos centrada en sistemas operativos y en la gestión de
      energía del computador. http://www.acpi.info/

.. image:: images/monitor/thermal-info.png
   :scale: 70
   :align: center

Alertas
=======

Las gráficas no tendrían ninguna utilidad si no se ofreciera
notificaciones cuando se producen algunos valores de la
monitorización. De esta manera, podemos saber cuando la máquina está
sufriendo una carga inusual o está llegando a su máxima capacidad.

Las **alertas de monitorización** deben configurarse en el módulo de
eventos. Entrando en :menuselection:`Eventos --> Configurar eventos`, podemos
ver la lista de eventos disponibles, los eventos de monitorización están
agrupados en el vento **Monitor**.


.. image:: images/monitor/monitor-watchers.png
   :scale: 70
   :align: center


Pulsando en la celda de configuración, accederemos a la configuración de este
evento. Podremos elegir cualquiera de las métricas monitorizadas y establecer
umbrales  que disparen el evento.


.. image:: images/monitor/monitor-threshold.png
   :scale: 70
   :align: center


En cuanto a los umbrales tendremos de dos tipos, de *advertencia* y de *fallo*,
pudiendo así discriminar entre la gravedad del evento. Tenemos la opción de
:guilabel:`invertir:` que hará que los valores considerados correctos sean considerados
fallos y a la inversa. Otra opción importante es la de
:guilabel:`persistente:`. Dependiendo de la métrica también
podremos elegir otros parámetros relacionados con esta, por ejemplo
para el disco duro podemos recibir alertas sobre el espacio libre, o
para la carga puede ser útil la carga a corto plazo, etc.

Cada medida tiene una métrica que se describe como sigue:

Carga del sistema:
  Los valores deben ser en **número de tareas ejecutables media en la
  cola de ejecución**.

Uso de la CPU:
  Los valores se deben disponer en **jiffies** o unidades de
  *scheduling*.

Uso de la memoria física:
  Los valores deben establecerse en **bytes**.

Sistema de ficheros:
  Los valores deben establecerse en **bytes**.

Temperatura:
  Los valores a establecer debe establecer en **grados**.

Una vez configurado y activado el evento deberemos configurar al menos un
observador para recibir las alertas. La configuración de los observadores es
igual que la de cualquier evento, así que deberemos seguir las indicaciones
contenida en el capítulo de :ref:`events-ref`.

.. include:: monitor-exercises.rst
