Encaminamiento
**************

.. sectionauthor:: Isaac Clerencia <iclerencia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>
                   Víctor Jímenez <vjimenez@warp.es>,

Tablas de encaminamiento
========================

El término **encaminamiento** hace referencia a la acción de decidir
a través de qué interfaz debe ser enviado un determinado paquete que va a
salir desde una máquina. El sistema operativo cuenta con una tabla de
encaminamiento con un conjunto de reglas para tomar esta decisión.

Cada una de estas reglas cuenta con diversos campos, pero los tres más
importantes son: :guilabel:`dirección de destino`,
:guilabel:`interfaz` y :guilabel:`router`. Se deben de leer como
sigue: para llegar a una :guilabel:`dirección de destino` dada,
tenemos que dirigir el paquete a través de un :guilabel:`router`,
el cual es accesible a través de una determinada :guilabel:`interfaz`.

Cuando llega un mensaje, se compara su dirección destino con las entradas en la
tabla y se envía por la interfaz indicada en la regla cuya dirección mejor
coincide con el destino del paquete, es decir, aquella regla que es
más específica. Por ejemplo, si se especifica una regla en la que
para alcanzar la red A (10.15.0.0/16) debe ir por el *router* A y otra
regla en la que para alcanzar la red B (10.15.23.0/24), la cual es una
subred de A, debe ir por el *router* B; si llega un paquete con destino
10.15.23.23/32, entonces el sistema operativo decidirá que se envíe al
*router B* ya que existe una regla más específica.

Todas las máquinas tienen al menos una regla de encaminamiento para la
interfaz de *loopback*, o interfaz local, y reglas adicionales para
otras interfaces que la conectan con otras redes internas o con
Internet.

Para realizar la configuración manual de una tabla de rutas estáticas
se utiliza :menuselection:`Red --> Rutas` (interfaz para el comando
**route** o **ip route**). Estas rutas pueden ser sobreescritas si se
utiliza el protocolo DHCP.

.. figure:: images/routing/11-routing.png
   :scale: 60
   :alt: Configuración de rutas
   :align: center

   Configuración de rutas

Puerta de enlace
----------------

A la hora de enviar un paquete, si ninguna ruta coincide y hay una puerta de
enlace configurada, éste se enviará a través de la puerta de enlace.

La **puerta de enlace** (*gateway*) es la ruta por omisión para los paquetes que
se envían a otras redes.

Para configurar una puerta de enlace se utiliza :menuselection:`Red
--> Puertas de enlace`.

.. image:: images/routing/11-routing-gateways.png
   :scale: 80
   :alt: Configuración de puertas de enlace
   :align: center

Habilitado:
  Indica si realmente esta puerta de enlace es efectiva o está desactivada.
Nombre:
  Nombre por el que identificaremos a la puerta de enlace.
Dirección IP:
  Dirección IP de la puerta de enlace. Esta dirección debe ser accesible desde
  la máquina que contiene eBox.
Interfaz:
  Interfaz de red conectada a la puerta de enlace. Los paquetes que se envíen a
  la puerta de enlace se enviarán a través de esta interfaz.
Peso:
  Cuanto mayor sea el peso, más tráfico absorberá esa puerta de enlace cuando
  esté activado el balanceo de carga.
Default:
  Si está activado, se toma esta como la puerta de enlace por omisión.

Si se tienen interfaces configuradas como DHCP o PPPoE no se pueden añadir
puertas de enlace explíticamente para ellas, dado que ya son gestionadas
automáticamente. A pesar de eso, se pueden seguir activando o desactivando,
editando su :guilabel:`Peso` o elegir el :guilabel:`Predeterminado`,
pero no se pueden editar el resto de los atributos.

.. image:: images/routing/dynamic-gateways.png
   :scale: 80
   :alt: Lista de puertas de enlace con DHCP y PPPoE
   :align: center

   Lista de puertas de enlace con DHCP y PPPoE

Ejemplo práctico A
^^^^^^^^^^^^^^^^^^

Vamos a configurar la interfaz de red de manera estática. La clase quedará
dividida en dos subredes.

Para ello:

#. **Acción:**
   Acceder a la interfaz de eBox, entrar en :menuselection:`Red -->
   Interfaces` y seleccionar para el :guilabel:`interfaz de red`
   *eth0* el :guilabel:`método` *Estático*.  Como :guilabel:`dirección
   IP` introducir la que indique el instructor.  Como
   :guilabel:`Máscara de red` 255.255.255.0. Pulsar el botón
   :guilabel:`Cambiar`.

   La dirección de red tendrá la forma 10.1.X.Y, dónde 10.1.X corresponde con
   la red e Y con la máquina. En adelante usaremos estos valores.

   Entrar en :menuselection:`Red --> DNS` y seleccionar :guilabel:`Añadir`. Introducir como
   :guilabel:`Servidor de nombres` 10.1.X.1. Pulsar :guilabel:`Añadir`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios` y la interfaz de red mantiene
     los datos introducidos. Ha aparecido una lista con los servidores de
     nombres en la que aparece el servidor recién creado.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios.

#. **Acción:**
   Acceder a :menuselection:`Red --> Diagnóstico`. Hacer ping a ebox-platform.com.

   Efecto:
     Se muestra como resultado::

       connect: Network is unreachable

#. **Acción:**
   Acceder a :menuselection:`Red --> Diagnóstico`. Hacer ping a una eBox de un compañero de
   aula que forme parte de la misma subred.

   Efecto:
     Se muestran como resultado tres intentos satisfactorios de conexión con
     la máquina.

#. **Acción:**
   Acceder a :menuselection:`Red --> Diagnóstico`. Hacer ping a una
   eBox de un compañero de aula que esté en la otra subred.

   Efecto:
     Se muestra como resultado::

       connect: Network is unreachable

Ejemplo práctico B
^^^^^^^^^^^^^^^^^^

Vamos a configurar una ruta para poder acceder a máquinas de otras subredes.

Para ello:

#. **Acción:**
   Acceder a la interfaz de eBox, entrar en :menuselection:`Red --> Rutas` y seleccionar
   :guilabel:`Añadir nuevo`. Rellenar el formulario con los siguientes valores:

   :Network:     10.1.X.0 / 24
   :Gateway:     10.1.1.1
   :Description: Ruta a la otra subred

   Pulsar el botón :guilabel:`Añadir`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`. Ha aparecido una lista de
     rutas en la que se incluye la ruta recién creada.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios.


#. **Acción:**
   Acceder a :menuselection:`Red --> Diagnóstico`. Hacer ping a ebox-platform.com.

   Efecto:
     Se muestra como resultado::

       connect: Network is unreachable

#. **Acción:**
   Acceder a :menuselection:`Red --> Diagnóstico`. Hacer ping a una eBox de un compañero de
   aula que esté en la otra subred.

   Efecto:
     Se muestran como resultado tres intentos satisfactorios de conexión con
     la máquina.

Ejemplo práctico C
^^^^^^^^^^^^^^^^^^

Vamos a configurar una puerta de enlace que nos conecte con el resto de redes.

Para ello:

#. **Acción:**
   Acceder a la interfaz de eBox, entrar en :menuselection:`Red --> Rutas` y eliminar la ruta
   creada en el ejercicio anterior.

   Entrar en :menuselection:`Red --> Puertas de enlace` y selecciona
   :guilabel:`Añadir nuevo`. Rellenar con los siguientes datos:

   :Nombre:     Default Gateway
   :IP Address: 10.1.X.1
   :Interface:  eth0
   :Weight:     1
   :Default:    sí

   Pulsar el botón :guilabel:`Añadir`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`. Ha
     desaparecido la lista de rutas. Ha aparecido una lista de puertas
     de enlace con la puerta de enlace recién creada.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios.


#. **Acción:**
   Acceder a :menuselection:`Red --> Diagnóstico`. Hacer ping a
   ebox-platform.com.

   Efecto:
     Se muestran como resultado tres intentos satisfactorios de conexión con
     la máquina.

#. **Acción:**
   Acceder a :menuselection:`Red --> Diagnóstico`. Hacer ping a una
   eBox de un compañero de aula que esté en la otra subred.

   Efecto:
     Se muestran como resultado tres intentos satisfactorios de conexión con
     la máquina.

.. _multigw-section-ref:

Reglas multirouter y balanceo de carga
======================================

Las **reglas multirouter** son una herramienta que permite a los
computadores de una red utilizar varias conexiones a *Internet* de una
manera transparente. Esto es útil si, por ejemplo, una oficina dispone
de varias conexiones ADSL y queremos poder utilizar la totalidad del
ancho de banda disponible sin tener que preocuparnos de repartir el
trabajo manualmente de las máquinas entre ambos *routers*, de tal manera
que la carga se distribuya automáticamente entre ellos.

El **balanceo de carga** básico reparte de manera equitativa los paquetes que salen
de eBox hacia *Internet*. La forma más simple de configuración es establecer
diferentes **pesos** para cada *router*, de manera que si las conexiones de las que
se dispone tienen diferentes capacidades podemos hacer un uso óptimo
de ellas.

Las reglas *multirouter* permiten hacer que determinado tipo de tráfico se envíe
siempre por el mismo *router* en caso de que sea necesario. Ejemplos comunes son
enviar siempre el correo electrónico por un determinado *router* o hacer que una
determinada subred siempre salga a Internet por el mismo *router*.

eBox utiliza las herramientas **iproute2** e **iptables** para llevar
a cabo la configuración necesaria para la funcionalidad de
*multirouter*. Mediante **iproute2** se informa al *kernel* de la
disponibilidad de varios *routers*. Para las reglas *multirouter* se
usa **iptables** para marcar los paquetes que nos interesan.  Estas
marcas pueden ser utilizadas desde **iproute2** para determinar el
*router* por el que un paquete dado debe ser enviado.

Hay varios posibles problemas que hay que tener en cuenta. En primer lugar en
**iproute2** no existe el concepto de conexión, por lo que sin ningún otro
tipo de configuración los paquetes pertenecientes a una misma conexión podrían
acabar siendo enviados por diferentes *routers*, imposibilitando
la comunicación. Para solucionar esto se utiliza **iptables** para identificar
las diferentes conexiones y asegurarnos que todos los paquetes de una conexión
se envían por el mismo *router*.

Lo mismo ocurre con las conexiones entrantes que se establecen, todos los
paquetes de respuesta a una conexión deben ser enviados por el mismo
*router* por el cual se recibió esa conexión.

Para establecer una configuración *multirouter* con balanceo de carga
en eBox debemos definir tantos *routers* como sean necesarios en
:menuselection:`Red --> Puertas de enlace`.  Utilizando el parámetro
:guilabel:`peso` en la configuración de un *router* podemos determinar
la proporción de paquetes que cada uno de ellos enviará. Si se dispone
de dos *routers* y establecemos unos pesos de 5 y 10 respectivamente,
por el primer *router* se enviarán 5 de cada 15 paquetes mientras que
los otros 10 restantes se enviarán a través del segundo.

.. image:: images/routing/01-gateways.png
   :scale: 80
   :align: center

Las reglas *multirouter* y el balanceo de tráfico se establecen en la
sección :menuselection:`Red --> Balanceo de tráfico`. En esta sección
podemos añadir reglas para enviar ciertos paquetes a un determinado
*router* dependiendo de la :guilabel:`interfaz` de entrada, la
:guilabel:`fuente` (puede ser una dirección IP, un objeto, eBox o
cualquiera), el :guilabel:`destino` (una dirección IP o un objeto de
red), el :guilabel:`servicio` al que se quiere asociar esta regla y
por cual de los :guilabel:`routers` queremos direccionar el tipo de
tráfico especificado.

.. image:: images/routing/02-gateway-rules.png
   :scale: 80
   :align: center

Ejemplo práctico D
------------------

Configurar un escenario *multirouter* con varios *routers* con diferentes pesos
y comprobar que funciona utilizando la herramienta **traceroute**.

Para ello:

#. **Acción:**
   Ponerse por parejas, dejando una eBox con la configuración actual y añadiendo
   en la otra un nuevo *gateway*, accediendo a través del interfaz a
   :menuselection:`Red --> Puertas de enlace` y pulsando en :guilabel:`Añadir nuevo`,
   con los siguientes datos:

   :Nombre:         Gateway 2
   :Dirección IP:   <IP eBox compañero>
   :Interfaz:       eth0
   :Peso:           1
   :Predeterminado: sí

   Pulsar el botón :guilabel:`Añadir`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`. Ha aparecido una
     lista de puertas de enlace con la puerta de enlace recién creada y la
     puerta de enlace anterior.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios.

#. **Acción:**
   Ir a una consola y ejecutar el siguiente *script*::

      for i in $(seq 1 254); do sudo traceroute -I -n 155.210.33.$i -m 6; done

   Efecto:
     El resultado de una ejecución de **traceroute** muestra los
     diferentes *routers* por los que un paquete pasa para llegar a su
     destino. Al ejecutarlo en una máquina con configuración
     *multirouter* el resultado de los primeros saltos entre *routers*
     debería ser diferente dependiendo del *router* elegido.

Tolerancia a fallos (WAN Failover)
==================================

Si se está balanceando tráfico entre dos o más routers esta característica
es realmente útil. En un escenario normal sin tolerancia a fallos, supóngase
que se está balanceando el tráfico entre dos routers y uno de ellos se cae.
Asumiendo que los dos routers tengan el mismo peso, la mitad del tráfico
seguiría intentando salir por el router caído, causando problemas de
conectividad a todos los clientes de la red.

En la configuración del *failover* se pueden definir conjuntos de reglas
para cada router que necesite ser comprobado. Estas reglas pueden ser un
*ping* al router, a un host externo, una resolución de DNS o una petición
HTTP. También se puede definir cuántas pruebas se quieren realizar así
como el porcentaje de aceptación exigido. Si cualquiera de las pruebas falla,
no llegando al porcentaje de aceptación, el router asociado a ella será
desactivado. Pero las pruebas se siguen ejecutando, por tanto, en cuanto
el router vuelva a estar operativo, todas las pruebas se ejecutarán
satisfactoriamente y el router será activado de nuevo.


El deshabilitar un router sin conexión tiene como consecuencia que todo
el tráfico salga por el otro router que sigue habilitado, en lugar de
ser balanceado. De esta forma los usuarios de la red no deberían sufrir
grandes inconvenientes con la conexión. Una vez que eBox detecta que el
router caído está completamente operativo se restaura el comportamiento
normal de balanceo de tráfico.


El *failover* está implementado como un evento de eBox. Para usarlo,
primero se necesita tener el módulo :guilabel:`Eventos` habilitado, y
posteriormente habilitar el evento :guilabel:`WAN Failover`. Para más
detalles acerca de cómo funcionan y como se configuran los eventos en
eBox se puede consultar el capítulo :ref:`events-ref`.

.. image:: images/routing/failover.png
   :scale: 80
   :align: center

Para configurar las opciones y reglas del *failover* se debe acudir
al menú :menuselection:`Network --> WAN Failover`. Se puede especificar
el periodo del evento modificando el valor de la opción
:guilabel:`Tiempo entre revisiones`. Para añadir una regla simplemente
hay que pulsar la opción :guilabel:`Añadir nueva` y aparecerá un
formulario con los siguientes campos:

- :guilabel:`Habilitado`: Indica si la regla va a ser aplicada o no
  durante la comprobación de conectividad de los routers. Se pueden
  añadir distintas reglas y habilitarlas o deshabilitarlas de acuerdo
  las necesidades, sin tener que borrarlas y añadirlas de nuevo.
- :guilabel:`Router`: Se encuentra previamente rellenado con la lista de
  routers configurados, solo se necesita seleccionar uno de ellos.
- :guilabel:`Tipo de prueba`: Puede tomar uno de los siguientes valores:

  - :guilabel:`Ping a puerta de enlace`: Envía un paquete ICMP echo con
    la dirección de la puerta de enlace como destino.
  - :guilabel:`Ping a máquina`: Envía un paquete ICMP echo con la dirección
    IP de la máquina externa especificada abajo como destino.
  - :guilabel:`Resolución DNS`: Intenta obtener la dirección IP para el
    nombre de máquina especificado abajo.
  - :guilabel:`Petición HTTP`: Se descarga el contenido del sitio web
    especificado abajo.

- :guilabel:`Máquina`: El servidor que se va a usar como objetivo en la prueba.
  No es aplicable en caso de :guilabel:`Ping a puerta de enlace`.
- :guilabel:`Número de pruebas`: Número de veces que se repite la prueba.
- :guilabel:`Ratio de éxito requerido`: Indica que proporción de intentos
  satisfactorios es necesaria para considerar correcta la prueba.

Se recomienda configurar un emisor de eventos para enterarse de las conexiones
y desconexiones de routers que puedan producirse. Si no se hace esto, los
eventos serán registrados sólamente en el fichero `/var/log/ebox/ebox.log`.

.. include:: routing-exercises.rst
