.. _advanced-proxy-ref:

Configuración Avanzada para el proxy HTTP
*****************************************

.. sectionauthor:: Javier Amor García <javier.amor.garcia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,

Filtrado basado en grupos de usuarios
=====================================

Es posible usar los grupos de usuarios en el control de acceso y en el
filtrado. Para ello primero debemos usar como política global o del
objeto de red desde el cuál accedemos al *proxy*, una de las siguientes:
**Autorizar y permitir todo**, **Autorizar y denegar todo** o
**Autorizar y filtrar**.

Estas políticas hacen que el *proxy* pida identificación de usuario y
de no ser satisfactoria se bloqueará el acceso.

.. warning::
  Hay que tener en cuenta que, por una limitación técnica de la
  autenticación HTTP, las políticas con autenticación  son incompatibles con
  el modo transparente.

Si tenemos establecida una política global con autorización podremos
también establecer políticas globales de grupo, la política nos
permitirá controlar el acceso a los miembros del grupo y asignarle un
perfil de filtrado distinto del perfil por defecto.

Las políticas de grupo se gestionan en la sección
:menuselection:`Proxy HTTP --> Política de Grupo`.  El acceso del
grupo puede ser permitir o denegar. Esto sólo afecta al acceso a la
web, la activación del filtrado de contenidos no depende de esto sino
de que tengamos una política global o de objeto de filtrar.  A la
política de grupo se le puede asignar un horario, fuera del horario el
acceso será denegado.

.. image:: images/proxy/global-group-policy.png
   :align: center
   :scale: 80

Cada política de grupo tiene una prioridad reflejada en su posición en
la lista (primero en la lista, mayor prioridad). La prioridad es
importante ya que hay usuarios que pueden pertenecer a varios
grupos, en cuyo caso le afectarán únicamente las políticas adoptadas al
grupo de mayor prioridad.

También aquí se le puede asignar un perfil de filtrado para ser usado
cuando se realice filtrado de contenidos a miembros del grupo de
usuarios. En la próxima sección se explica el uso de los perfiles de
filtrado.

Filtrado basado en grupos de usuarios para objetos
==================================================

Recordamos que es posible configurar políticas por objeto de
red. Dichas políticas tienen prioridad sobre la política general del
*proxy* y sobre las políticas globales de grupo.

Además en caso de que hayamos elegido una política con autorización,
es posible también definir políticas por grupo. Las políticas de grupo
en este caso sólo influyen en el acceso y no en el filtrado que vendrá
determinado por la política de objeto. Al igual que en la política
general, las políticas con autorización son incompatibles con el
filtrado transparente.

Por último, cabe destacar que no podemos asignar perfiles de filtrado a los
grupos en las políticas de objeto. Por tanto, un grupo usará el perfil de
filtrado establecido en su política global de grupo, sea cual sea el objeto de
red desde el que se acceda al *proxy*.

.. image:: images/proxy/object-group-policy.png
   :align: center
   :scale: 80

Configuración de perfiles de filtrado
=====================================

La configuración de perfiles de filtrado se realiza en la sección
:menuselection:`Proxy HTTP --> Perfiles de Filtrado`.

.. image:: images/proxy/filter-profiles.png
   :align: center
   :scale: 80

Se pueden crear nuevos perfiles de filtrado y configurarlos.  Las
opciones de configuración son idénticas a las explicadas en la
configuración del perfil por defecto, con una importante salvedad: es
posible usar la misma configuración del perfil por defecto en las
distintas áreas de configuración. Para ello basta con marcar la
opción :guilabel:`Usar configuración por defecto`.

Ejemplo práctico
^^^^^^^^^^^^^^^^

Tenemos que crear una política de acceso para dos grupos: **IT** y
**Contabilidad**.  Los miembros del grupo de contabilidad sólo podrán
acceder en horario de trabajo y tendrán el contenido filtrado con
mayor umbral que el resto de la empresa. Los miembros de IT podrán
entrar a cualquier hora, no tendrán filtrado pero tendrán denegada la
misma listas de dominios que el resto de la empresa. Asumimos que los
grupos y sus usuarios ya están creados.

Para ello, podemos seguir estos pasos:

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activar el módulo :guilabel:`Proxy`, para ello marcar su casilla en
   la columna :guilabel:`Estado`.

   Efecto:
     Una vez los cambios guardados, se pedirá autenticación a todo el
     que trate de acceder al contenido web y de acceder el filtrado
     de contenidos estará activado.

#. **Acción:**
   Entrar a la gestión de perfiles de filtrado, situada en
   :menuselection:`Proxy HTTP --> Perfiles de Filtrado`.  Primero,
   agregar al perfil por defecto la lista de dominios prohibidos
   por la empresa. Entrar por medio del icono en la columna de
   :guilabel:`Configuración` a los parámetros del perfil por defecto.
   Seleccionar la pestaña :guilabel:`Filtrado de dominios` y en la
   lista de dominios añadir *marca.es* y *youtube.com*.

   A continuación, volver a :menuselection:`Proxy HTTP --> Perfiles
   de Filtrado`, y crear dos nuevos perfiles de filtrado para
   nuestros grupos, con los nombres *Perfil IT* y *Perfil
   contabilidad*. Seguidamente configuraremos ambos.

   El *Perfil contabilidad* tan sólo debe distinguirse por la poca
   tolerancia de su umbral, así que en umbral de filtrado lo
   estableceremos al valor *muy estricto*, el resto de configuración
   debe seguir la política por defecto de la empresa así que tanto en
   :guilabel:`Filtro de dominios`, como en :guilabel:`Filtro de
   extensiones de fichero` y en :guilabel:`Filtro de tipos MIME`
   marcaremos la opción :guilabel:`Usar configuración por defecto`
   asegurándonos así que el comportamiento para estos elementos no
   diferirá de la política por defecto.

   En el *Perfil IT* debemos dejar libre acceso a todo menos a los
   dominios prohibidos, para los que debemos seguir la política
   habitual.  En consecuencia iremos a :guilabel:`Filtro de dominios`
   y marcaremos la opción :guilabel:`Usar configuración por defecto`,
   el nivel de umbral lo dejaremos en *Desactivado* y las listas de
   filtrado de extensiones de fichero y tipos MIME, vacías.

   Efecto:
     Tendremos definidos los perfiles de filtrado necesarios para
     nuestros grupos de usuarios.

#. **Acción:**
   Ahora asignaremos los horarios y los perfiles de filtrado a los
   grupos. Para ello entraremos en :menuselection:`Proxy HTTP -->
   Política de grupo`.

   Pulsaremos sobre :guilabel:`Añadir nueva`, seleccionaremos
   *Contabilidad* como grupo, estableceremos el horario de lunes a
   viernes de 9:00 a 18:00 y seleccionaremos el perfil de filtrado
   *Perfil de contabilidad*.

   De igual manera crearemos una política para el grupo IT. Para este
   grupo seleccionaremos el *Perfil IT* y no pondremos ninguna
   restricción en cuanto horario.

   Efecto:
     Una vez guardados los cambios, habremos finalizado la
     configuración para este caso. Entrando con usuarios
     pertenecientes a uno u otro grupo podremos comprobar de las dos
     políticas. Algunas cosas que podemos comprobar:

     * Entrar como miembro de contabilidad en *www.playboy.com* y
       comprobar que es denegada por el análisis de contenidos. A
       continuación entrar como miembro de IT y comprobar que el
       análisis esta desactivado entrando en dicha página.

     * Tratar de entrar en alguno de los dominios prohibidos,
       comprobando que la lista está en vigor para ambos grupos.

     * Cambiar la fecha a un día no laborable, comprobar que los
       miembros de IT pueden acceder pero los de Contabilidad, no.

.. include:: advancedproxy-exercises.rst
