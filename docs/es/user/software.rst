.. _software-ref:

Actualización de software
+++++++++++++++++++++++++

.. sectionauthor:: Javier Amor García <javier.amor.garcia@ebox-platform.com>
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>

Como todo sistema de *software*, eBox Platform requiere actualizaciones
periódicas, bien sea para añadir nuevas características o para reparar
defectos o fallos del sistema.

eBox distribuye su *software* mediante paquetes y usa la herramienta
estándar de Ubuntu, **APT** [#]_, sin embargo para facilitar la tarea
ofrece una interfaz web que simplifica el proceso. [#]_

.. [#] *Advanced Packaging Tool* (APT) es un sistema de gestión de
       paquetes *software* creado por el proyecto Debian que
       simplifica en gran medida la instalación y eliminación de
       programas en el sistema operativo GNU/Linux
       http://wiki.debian.org/Apt

.. manual

.. [#] Para una explicación más extensa sobre la instalación de
       paquetes *software* en Ubuntu, leer la sección
       :ref:`package-tool-ref`.

.. endmanual

.. web

.. [#] Para una explicación más extensa sobre la instalación de
       paquetes *software* en Ubuntu, leer el capítulo al respecto
       de la documentación oficial
       https://help.ubuntu.com/8.04/serverguide/C/package-management.html

.. endweb

Mediante la interfaz web podremos ver para qué componentes de eBox está
disponible una nueva versión e instalarlos de un forma sencilla.
También podemos actualizar el *software* en el que se apoya eBox,
principalmente para corregir posibles fallos de seguridad.

Gestión de componentes de eBox
==============================

La **gestión de componentes de eBox** permite instalar, actualizar y
eliminar módulos de eBox.

El propio gestor de componentes es un módulo más, y como cada módulo de
eBox, debe ser habilitado antes de ser usado. Para
gestionar los componentes de eBox debemos entrar en
:menuselection:`Gestión de Software--> Componentes de eBox`.

.. image:: images/software/software-ebox-components.png
   :scale: 80
   :align: center

Presenta una lista con todos los componentes de eBox, así como la
versión instalada y la ultima versión disponible. Aquellos componentes
que no estén instalados o actualizados, pueden instalarse o
actualizarse pulsando en el icono correspondiente en la columna de
*Acciones*. Existe un botón de *Actualizar todos los paquetes* para
actualizar todos aquellos que tengan actualización disponible.

También podemos desinstalar componentes pulsando el icono apropiado
para esta acción. Antes de realizar la desinstalación, se muestra un
diálogo con la lista de aquellos paquetes de *software* que se van a
eliminar. Este paso es necesario porque hemos podido querer eliminar
un componente que al ser usados por otros conlleva también la
eliminación de los últimos.

Algunos componentes son básicos y no pueden desinstalarse, ya que
haría que se desinstalase eBox Platform.

Actualizaciones del sistema
===========================

Las **actualizaciones del sistema** actualizan programas usados por
eBox. Para llevar a cabo su función, eBox Platform usa diferentes
programas del sistema para llevar a cabo sus funciones, en los
distintos paquetes de los componentes de eBox. Dichos programas son
referenciados como **dependencias** asegurando que al instalar eBox,
son instalados también ellos asegurando el correcto funcionamiento de
eBox Platform. De manera análoga, estos programas pueden tener
dependencias también.

Normalmente una actualización de una dependencia no es suficientemente
importante como para crear un nuevo paquete de eBox con nuevas dependencias, pero
sí puede ser interesante instalarla para aprovechar sus mejoras o sus
soluciones frente a fallos de seguridad.

.. figure:: images/software/system-updates.png
   :scale: 70
   :align: center
   :alt: Actualizaciones del sistema

   Actualizaciones del sistema

Para ver las actualizaciones del sistema debemos ir a
:menuselection:`Gestión de Sofware --> Actualizaciones del
sistema`. Debe aparecer una lista de los paquetes que podemos
actualizar o si el sistema está ya actualizado. Si se instalan
paquetes en la maquina por otros medios que no sea la interfaz web,
los datos de esta pueden quedar desactualizados. Por ello, cada noche
se ejecuta el proceso de búsqueda de actualizaciones a instalar en el
sistema. Si se quiere forzar dicha búsqueda se puede hacer ejecutando::

   $ sudo ebox-software

Para cada una de las actualizaciones podemos determinar si es de
seguridad o no con el icono indicativo de más información. Si es una
actualización de seguridad podemos ver el fallo de seguridad con el
registro de cambios del paquete, pulsando sobre el icono.

Si queremos actualizar tendremos que seleccionar aquellos paquetes
sobre los que realizar la acción y pulsar el botón
correspondiente. Como atajo también tenemos un botón de
:guilabel:`Actualizar todos los paquetes`. Durante la actualización se
irán mostrando mensajes sobre el progreso de la operación.

Actualizaciones automáticas
===========================

Las **actualizaciones automáticas** consisten en que eBox Platform
automáticamente instala cualquier actualización disponible. Dicha
actualización se realiza cada noche a la medianoche.

Podremos activar esta característica accediendo a la pagina
:menuselection:`Gestión de Software --> Actualizaciones automáticas`.`

.. image:: images/software/software-automatic-updates.png
   :scale: 80
   :align: center

No es aconsejable usar esta opción si el administrador quiere tener
una mayor seguridad en la gestión de sus actualizaciones.
Realizando la actualizaciones manualmente se facilita que
posibles errores en las mismas no pasen desapercibidos.

.. include:: software-exercises.rst
