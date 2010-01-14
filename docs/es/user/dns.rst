Servicio de resolución de nombres (DNS)
***************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Isaac Clerencia <iclerencia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Víctor Jímenez <vjimenez@warp.es>,
                   Jorge Salamero <jsalamero@ebox-platform.com>,
                   Javier Uruen <juruen@ebox-platform.com>,

La funcionalidad de **DNS** *(Domain Name System)* es
convertir nombres de máquinas, legibles y fáciles de recordar por los usuarios,
en direcciones IP y viceversa. El sistema de dominios de nombres es
una arquitectura arborescente cuyos objetivos son evitar la
duplicación de la información y facilitar la búsqueda de dominios. El servicio
escucha peticiones en el puerto 53 de los protocolos de transporte UDP y TCP.

Configuración de un servidor *caché* DNS con eBox
=================================================

Un servidor de nombres puede actuar como *caché* [#]_ para las consultas que
él no puede responder. Es decir, la primera vez consultará al servidor
adecuado porque se parte de una base de datos sin información, pero
posteriormente responderá la *caché*, con la consecuente disminución del tiempo
de respuesta.

.. [#] *Caché* es una colección de datos duplicados de una fuente
   original donde es costoso de obtener o calcular comparado con el
   tiempo de lectura de la *caché* (http://en.wikipedia.org/wiki/Cache)

En la actualidad, la mayoría de los sistemas operativos modernos tienen una
biblioteca local para traducir los nombres que se encarga de almacenar
una *caché* propia de nombres de dominio con las peticiones realizadas
por las aplicaciones del sistema (navegador, clientes de correo, ...).

Ejemplo práctico A
------------------

Comprobar el correcto funcionamiento del servidor *caché* DNS.
¿Qué tiempo de respuesta hay ante la misma petición *www.example.com*?

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activar el módulo **DNS**, para ello marcar su casilla en la columna
   :guilabel:`Estado`.

   Efecto:
     eBox solicita permiso para sobreescribir algunos ficheros.

#. **Acción:**
   Leer los cambios de cada uno de los ficheros que van a ser modificados y
   otorgar permiso a eBox para sobreescribirlos.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Ir a :menuselection:`Red --> DNS` y añadir un nuevo
   :guilabel:`Servidor de nombres de dominio` con valor 127.0.0.1 .

   Efecto:
     Establece que sea la propia eBox la que traduzca de nombres a IP
     y viceversa.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     Ahora eBox gestiona la configuración del servidor DNS.

#. **Acción:**
    Comprobar a través de la herramienta :guilabel:`Resolución de
    Nombres de Dominio` disponible en :menuselection:`Red -->
    Diagnóstico` comprobar el funcionamiento de la *caché* consultado el
    dominio *www.example.com* consecutivamente y comprobar el tiempo
    de respuesta.

Configuración de un servidor DNS con eBox
=========================================

DNS posee una estructura en árbol y el origen es conocido como '.' o raíz. Bajo
el '.' existen los TLD *(Top Level Domains)* como org, com, edu, net, etc.
Cuando se busca en un servidor DNS, si éste no conoce la respuesta, se buscará
recursivamente en el árbol hasta encontrarla. Cada '.' en una dirección (por
ejemplo, *home.example.com*) indica una rama del árbol de DNS diferente y un
ámbito de consulta diferente que se irá recorriendo de derecha a izquierda.

.. _dns-tree-fig:

.. figure:: images/dns/domain-name-space.png
   :scale: 70

   Árbol de DNS

Como se puede ver en la figura :ref:`dns-tree-fig`, cada zona tiene un
servidor de nombre autorizado [#]_. Cuando un cliente hace una
petición a un servidor de nombres, delega la resolución a aquel
servidor de nombres apuntado por el registro **NS** que dice ser
autoridad para esa zona. Por ejemplo, un cliente pide la dirección IP
de *www.casa.example.com* a un servidor que es autoridad para
*example.com*. Como el servidor tiene un registro que le indica el
servidor de nombres que es autoridad para la zona *casa.example.com*
(el registro NS), entonces delega la respuesta a ese servidor que
debería saber la dirección IP para esa máquina.

.. [#] Un servidor DNS es autoridad para un dominio cuando es aquel
   que tiene toda la información para resolver la consulta para ese
   dominio

Otro aspecto importante es la resolución inversa (*in-addr.arpa*), ya
que desde una dirección IP podemos traducirla a un nombre del
dominio. Además a cada nombre asociado se le pueden añadir tantos
alias (o nombres canónicos) como se desee, así una misma dirección IP
puede tener varios nombres asociados.

Una característica también importante del DNS es el registro
**MX**. Dicho registro indica el lugar donde se enviarán los correos
electrónicos que quieran enviarse a un determinado dominio. Por
ejemplo, si queremos enviar un correo a alguien@casa.example.com, el
servidor de correo preguntará por el registro MX de *casa.example.com*
y el servicio responderá que es *mail.casa.example.com*.

La configuración en eBox se realiza a través del menú
:menuselection:`DNS`. En eBox, se pueden configurar tantos dominios
DNS como deseemos.

Para configurar un nuevo dominio, desplegamos el formulario pulsando
:guilabel:`Añadir nuevo`. Desde allí se configura el :guilabel:`nombre
del dominio` y una :guilabel:`dirección IP` opcional a la que hará
referencia el dominio.

.. image:: images/dns/03-dns.png
   :scale: 70

Una vez que hemos creado un dominio correcto, por ejemplo *casa.example.com*,
tenemos la posibilidad de rellenar la lista de **máquinas** (*hostnames*) para
el dominio. Se podrán añadir tantas direcciones IP como se deseen
usando los nombres que decidamos. La resolución inversa se añade
automáticamente. Además, para cada pareja nombre-dirección se podrán también poner
tantos alias como se deseen.

.. image:: images/dns/04-dns-hostname.png
   :scale: 70

Con eBox se establece automáticamente el servidor autorizado para los
dominios configurados a la máquina con nombre **ns**. Si esa máquina
no existe, entonces se usa 127.0.0.1 como servidor de nombres
autorizado. Si quieres configurar el servidor de nombres autorizado
manualmente para tus dominios (registros **NS**), ve a
:guilabel:`servidores de nombres` y elige una de las máquinas del
dominio o una personalizada. En el escenario típico, se configurará
una máquina con nombre **ns** usando como dirección IP una de las
configuradas en la sección :menuselection:`Red --> Interfaces`.

Como característica adicional, podemos añadir nombres de servidores de
correo a través de los :guilabel:`intercambiadores de correo` (*Mail
Exchangers*) eligiendo un nombre de los dominios en los que eBox es
autoridad o uno externo. Además se le puede dar una
:guilabel:`preferencia` cuyo menor valor es el que da mayor prioridad,
es decir, un cliente de correo intentará primero aquel servidor con
menor número de preferencia.

.. image:: images/dns/05-dns-mx.png
   :scale: 70

Para profundizar en el funcionamiento de DNS, veamos qué ocurre en función de la
consulta que se hace a través de la herramienta de diagnóstico **dig** que se
encuentra en :menuselection:`Red --> Diagnóstico`.

Si hacemos una consulta a uno de los dominios que hemos añadido, el propio
servidor DNS de eBox responde con la respuesta apropiada de manera inmediata.
En caso contrario, el servidor DNS lanza una petición a los servidores
DNS raíz, y responderá al usuario tan pronto como obtenga una respuesta de
éstos. Es importante tener en cuenta que los servidores de nombres
configurados en :menuselection:`Red --> DNS` son los usados por las aplicaciones
cliente para resolver nombres, pero el servidor DNS no los utiliza de ningún
modo. Si queremos que eBox resuelva nombres utilizando su propio DNS
debemos configurar 127.0.0.1 como servidor DNS primario en dicha sección.

.. _dns-exercise-ref:

Ejemplo práctico B
------------------
Añadir un nuevo dominio al servicio de DNS. Dentro de este dominio asignar
una dirección de red al nombre de una máquina. Desde otra máquina comprobar
usando la herramienta **dig** que resuelve correctamente.

#. **Acción:**
   Comprobar que el servicio DNS está activo a través de
   :menuselection:`Dashboard` en el *widget* :guilabel:`Estado de
   módulos`. Si no está activo, habilitarlo en :menuselection:`Estado
   de módulos`.

#. **Acción:**
     Entrar en :menuselection:`DNS` y en :guilabel:`Añadir
     nueva` introducimos el dominio que vamos a gestionar. Se
     desplegará una tabla donde podemos añadir nombres de máquinas,
     servidores de correo para el dominio y la propia dirección del
     dominio. Dentro de :guilabel:`Nombres de máquinas` procedemos de
     la misma manera añadiendo el nombre de la máquina y su dirección
     IP asociada.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox solicitará permiso para escribir los nuevos ficheros.

#. **Acción:**
   Aceptar sobreescribir dichos ficheros y guardar cambios.

   Efecto:
     Muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

#. **Acción:**
     Desde otro equipo conectado a esa red solicitamos la resolución del nombre
     mediante **dig**, siendo por ejemplo 10.1.2.254 la dirección de nuestra eBox
     y *mirror.ebox-platform.com* el dominio a resolver::

	$ dig mirror.ebox-platform.com @10.1.2.254

	; <<>> DiG 9.5.1-P1 <<>> mirror.ebox-platform.com @10.1.2.254
	;; global options:  printcmd
	;; Got answer:
	;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 33835
	;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 2

	;; QUESTION SECTION:
	;mirror.ebox-platform.com.      IN      A

	;; ANSWER SECTION:
	mirror.ebox-platform.com. 600   IN      A       87.98.190.119

	;; AUTHORITY SECTION:
	ebox-platform.com.      600     IN      NS      ns1.ebox-platform.com.
	ebox-platform.com.      600     IN      NS      ns2.ebox-platform.com.

	;; ADDITIONAL SECTION:
	ns1.ebox-platform.com.  600     IN      A       67.23.0.68
	ns2.ebox-platform.com.  600     IN      A       209.123.162.63

	;; Query time: 169 msec
	;; SERVER: 10.1.2.254#53(10.1.2.254)
	;; WHEN: Fri Mar 20 14:37:52 2009
	;; MSG SIZE  rcvd: 126

.. include:: dns-exercises.rst
