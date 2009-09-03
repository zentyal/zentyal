.. _abs-ref:

Abstracciones de red a alto nivel de eBox
*****************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Isaac Clerencia <iclerencia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Víctor Jímenez <vjimenez@warp.es>,
                   Javier Uruen <juruen@ebox-platform.com>,

Objetos de red
==============

Los **objetos de red** son una manera de dar un nombre a un elemento
de una red o a un conjunto de ellos. Sirven para simplificar y
consecuentemente facilitar la gestión de la configuración de la red,
pudiendo elegir comportamientos para dichos objetos.

Por ejemplo, pueden servir para dar un nombre significativo a
una dirección IP o a un grupo de ellas. Si es el segundo caso, en
lugar de definir reglas de acceso de cada una de las direcciones,
bastaría simplemente con definirlas para el objeto de red. Así,
todas las direcciones pertenecientes al objeto adquirirían dicha
configuración.

.. figure:: images/abstractions/objects-schema.png
   :scale: 70
   :align: center
   :alt: Representación de objetos de red

   *GRAPHIC:  Representación de objetos de red*


Gestión de los objetos de red con eBox
--------------------------------------

Para su gestión en eBox se debe ir al menú :menuselection:`Objetos`
y ahí se crean nuevos objetos, que tendrán asociado un
:guilabel:`nombre`, y una serie de miembros.

.. figure:: images/abstractions/01-objects.png
   :alt: Aspecto general del módulo de objetos de red

   Aspecto general del módulo de objetos de red

Se puede crear, editar y borrar objetos. Estos objetos serán usados
más tarde por otros módulos como por ejemplo en el cortafuegos, el *Web
caché proxy* o en el correo.

Cada uno de ellos tendrá al menos los siguientes valores:
:guilabel:`nombre`, :guilabel:`dirección IP` y :guilabel:`máscara de
red` utilizando notación CIDR. La dirección física sólo tendrá sentido
para miembros que representen una única máquina.

.. image:: images/abstractions/06-object-member.png
   :scale: 70
   :alt: Añadiendo un miembro

Los miembros de un objeto pueden solaparse con miembros de otros, con lo cual
hay que tener mucho cuidado al usarlos en el resto de módulos para
obtener la configuración deseada y no tener problemas de seguridad.

Servicios de red
================

Un **servicio de red** es la abstracción de uno o más protocolos de
aplicación que pueden ser usados en otros módulos como el cortafuegos
o el módulo de moldeado de tráfico.

La utilidad de los servicios es similar a la de los objetos. Si
veíamos que con los objetos podíamos hacer referencia fácilmente a un
conjunto de direcciones IP usando un nombre significativo, podemos así
mismo identificar un conjunto de puertos numéricos, difíciles de
recordar y engorrosos de teclear varias veces en distintas
configuraciones, con un nombre acorde a su función (típicamente el
nombre del protocolo de nivel 7 o aplicación que usa esos puertos).

.. figure:: images/abstractions/services-schema.png
   :alt: Conexión de un cliente a un servidor

   *GRAPHIC: Conexión de un cliente a un servidor*

Gestión de los servicios de red con eBox
----------------------------------------

Para su gestión en eBox se debe ir al menú
:menuselection:`Servicios` donde es posible crear nuevos servicios,
que tendrán asociado un nombre, una descripción y un indicador de si
el servicio es externo o interno. Un servicio es interno si los
puertos configurados para dicho servicio se están usando en la máquina
en la que está eBox instalado. Además cada servicio tendrá una serie
de miembros. Cada uno de ellos tendrá los siguientes valores:
:guilabel:`protocolo`, :guilabel:`puerto origen` y :guilabel:`puerto
destino`.

En todos estos campos podemos introducir el valor *cualquiera*, por
ejemplo para especificar servicios en los que sea indiferente el
puerto origen.

Hay que tener en cuenta que los servicios de red basados en el modelo
cliente/servidor que más se utilizan el cliente suelen utilizar un
puerto cualquiera aleatorio para conectarse a un puerto destino
conocido. Los puertos del 1 al 1023 se llaman puertos "bien conocidos" y
en sistemas operativos tipo Unix enlazar con uno de estos puertos
requiere acceso como superusuario. Del 1024 al 49.151 son puertos
registrados. Y del 49.152 al 65.535 son puertos efímeros y son utilizados
como puertos temporales, sobre todo por los clientes al comunicarse con
los servidores. Existe una lista de servicios de red conocidos
aprobada por la IANA [#]_ para los protocolos UDP y TCP en el fichero
`/etc/services`.

.. [#] La IANA (*Internet Assigned Numbers Authority*) es la entidad
       encargada de establecer los servicios asociados a puertos bien
       conocidos. La lista completa se encuentra en
       http://www.iana.org/assignments/port-numbers

El protocolo puede ser TCP, UDP, ESP, GRE o ICMP. También existe un
valor TCP/UDP para evitar tener que añadir dos veces un mismo puerto
que se use para ambos protocolos.

.. figure:: images/abstractions/services.png
   :alt: Aspecto general del módulo de servicios de red
   :scale: 80

   Aspecto general del módulo de servicios de red

Se puede crear, editar y borrar servicios. Estos servicios serán usados más
adelante en el cortafuegos o el moldeado de tráfico haciendo referencia
simplemente al nombre significativo.

Ejemplo práctico
^^^^^^^^^^^^^^^^
Crear un objeto y añadir lo siguiente: una máquina sin dirección MAC, una
máquina con dirección MAC y una dirección de red.

Para ello:

#. **Acción:**
   Acceder a :menuselection:`Objetos`. Añadir **máquinas de
   contabilidad**.

   Efecto:
     El objeto **máquinas de contabilidad** se ha creado.

#. **Acción:**
   Acceder a :guilabel:`Miembros` del objeto **máquinas de
   contabilidad**. Crear miembro **servidor contable** con una dirección IP
   de la red, por ejemplo, *192.168.0.12/32*. Crear otro miembro
   **servidor contable respaldo** con otra dirección IP, por ejemplo,
   *192.168.0.13/32* y una dirección MAC válida, por ejemplo,
   *00:0c:29:7f:05:7d*. Finalmente, crea el miembro **red de
   ordenadores contables** con dirección IP una subred de tu red
   local, como por ejemplo, *192.168.0.64/26*. Finalmente, ir a
   :guilabel:`Guardar cambios` para confirmar la configuración creada.

   Efecto:
     El objeto **máquinas de contabilidad** contendrá tres miembros
     **servidor contable**, **servidor contable respaldo** y **red de
     ordenadores contables** de forma permanente.

.. include:: abstractions-exercises.rst
