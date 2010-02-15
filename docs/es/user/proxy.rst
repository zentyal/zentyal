.. _proxy-http-ref:

Servicio Proxy HTTP
*******************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Isaac Clerencia <iclerencia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Víctor Jímenez <vjimenez@warp.es>,
                   Javier Uruen <juruen@ebox-platform.com>,
                   Javier Amor García <javier.amor.garcia@ebox-platform.com>,

Un servidor **Proxy Caché Web** se utiliza para reducir el consumo de
ancho de banda en una conexión HTTP (Web) [#]_, controlar su acceso,
mejorar la seguridad en la navegación e incrementar la velocidad de
recepción de páginas de la red.

.. [#] Para más información sobre el servicio HTTP, ir a la sección
      :ref:`web-section-ref`.

Un *proxy* es un programa que actúa de intermediario en la conexión a
un protocolo, en este caso el protocolo HTTP.  Al intermediar puede
modificar el comportamiento del protocolo, por ejemplo actuando de
*caché* o modificando los datos recibidos.

.. figure:: images/proxy/proxy-schema.png
   :scale: 60
   :alt:  Servidor Web - LAN - Cache - Internet - Cache - Servidor Web

El servicio de proxy HTTP suministrado por eBox ofrece las siguientes
funcionalidades:

 * Actúa de *caché* de contenidos acelerando la navegación y
   reduciendo el consumo de ancho de banda.
 * Restricción de acceso dependiendo de la dirección de red de origen,
   de usuario o de horario.
 * Anti-virus, bloqueando el acceso a contenidos infectados.
 * Restricción de acceso a determinados dominios y tipos de fichero.
 * Filtrado de contenidos.

eBox utiliza Squid [#]_ como *proxy*, apoyándose en Dansguardian [#]_ para
el control de contenidos.

.. [#] Squid: http://www.squid-cache.org *Squid Web Proxy Cache*
.. [#] Dansguardian: http://www.dansguardian.org *Web content filtering*

Configuración de política de acceso
===================================

La parte más importante de configurar el *proxy HTTP* es establecer la política
de acceso al contenido web a través de él. La política
determina si se puede acceder a la web y si se aplica
del filtro de contenidos.

El primer paso a realizar es definir una política global de
acceso. Podemos establecerla en la sección :menuselection:`Proxy HTTP
--> General`, seleccionando una de las seis políticas disponibles:


Permitir todo:
  Con esta política se permite a los usuarios navegar sin
  restricciones. Esta falta de restricciones no significa que no
  puedan disfrutar de las ventajas de la *caché* de páginas web.

Denegar todo:
  Esta política deniega el acceso web. A primera vista podría parecer
  poco útil ya que el mismo efecto se puede conseguir más fácilmente con
  una regla de cortafuegos. Sin embargo, como explicaremos
  posteriormente podemos establecer políticas particulares para cada
  *objeto de red*, pudiendo usar esta política para denegar por
  defecto y luego aceptar las peticiones web para determinados
  objetos.

Filtrar:
  Esta política permite el acceso y activa el filtrado de contenidos que puede
  denegar el acceso web según el contenido solicitado por los
  usuarios.

Autorizar y Filtrar, Autorizar y permitir todo, Autorizar y denegar todo:
  Estas políticas son versiones de las políticas anteriores que
  incluyen autorización. La autorización se explicará en la sección
  :ref:`advanced-proxy-ref`.

.. image:: images/proxy/general.png
   :align: center
   :scale: 80


Tras establecer la política global, podemos refinar nuestra política
asignando políticas particulares a objetos de red. Para asignarlas
entraremos en la sección :menuselection:`Proxy HTTP --> Política de
objetos`.

Podremos elegir cualquiera de las seis políticas para cada objeto;
cuando se acceda al *proxy* desde cualquier miembro del objeto esta
política tendrá preferencia sobre la política global. Una dirección
de red puede estar contenida en varios objetos distintos por lo que es
posible ordenar los objetos para reflejar la prioridad. Se aplicará la
política del objeto de mayor prioridad que contenga la dirección de
red. Además existe la posibilidad de definir un rango horario fuera
del cual no se permitira acceso al objeto de red.

.. warning::

   La opción de rango horario no es compatible para políticas que usen filtrado de
   contenidos.

.. figure:: images/proxy/03-proxy.png
   :alt: Políticas de acceso web para objetos de red
   :scale: 80


   Políticas de acceso web para objetos de red

Conexión al proxy y modo transparente
=====================================

Para conectar al *proxy* HTTP, los usuarios deben configurar su
navegador estableciendo eBox como *proxy web*. El método específico
depende del navegador, pero la información necesaria es la dirección
del servidor de eBox y el puerto donde acepta peticiones el *proxy*.

El *proxy* de eBox Platform únicamente acepta conexiones provenientes
de sus interfaces de red internas, por tanto, se debe usar una
dirección interna en la configuración del navegador.

El puerto por defecto es el 3128, pero se puede configurar desde la
sección :menuselection:`Proxy HTTP --> General`. Otros puertos típicos
para servicios de proxy web son el 8000 y el 8080.

Para evitar que los usuarios se salten cualquier control de usuario
sin pasar por el *proxy*, deberíamos tener denegado el tráfico HTTP en
nuestro cortafuegos.

Una manera de evitar la necesidad de configurar cada navegador es usar
el **modo transparente**. En este modo, eBox debe ser establecido como
puerta de enlace y las conexiones HTTP hacia las redes externas a eBox
(Internet) serán redirigidas al *proxy*.  Para activar este
modo debemos ir a la página :menuselection:`Proxy HTTP --> General` y
marcar la opción :guilabel:`proxy transparente`. Como veremos en
:ref:`advanced-proxy-ref`, el modo transparente es incompatible con
políticas que requieran autorización.

Por último, hay que tener en cuenta que el tráfico *Web* seguro
(HTTPS) no puede ser filtrado al estar cifrado. Si se quiere usar el
**proxy transparente** se debe establecer una regla en el cortafuegos
para las redes internas hacia Internet dando acceso garantizado al
tráfico HTTPS.

Control de parámetros de la *caché*
===================================

En el apartado :menuselection:`Proxy HTTP --> General` es posible
definir el tamaño de la *caché* en disco y qué direcciones están exentas
de su uso.

El tamaño de la *caché* controla el máximo de espacio usado para almacenar
los elementos web cacheados. El tamaño se establece en el campo
:guilabel:`Tamaño de ficheros de caché` que se puede
encontrar bajo el encabezado :guilabel:`Configuración General`.

Con un mayor tamaño se aumentará la probabilidad de que se pueda recuperar un
elemento desde la *caché*, pudiendo incrementar la velocidad de
navegación y reducir el uso de ancho de banda. Sin embargo, el
aumento de tamaño tiene como consecuencias negativas no sólo el
aumento de espacio usado en el disco duro sino también un aumento en
el uso de la memoria RAM, ya que la *caché* debe mantener índices a los
elementos almacenados en el disco duro.

Corresponde a cada administrador decidir cual es el tamaño óptimo para
la *caché* teniendo en cuenta las características de la máquina y el
tráfico web esperado.

Es posible indicar dominios que estén exentos del uso de la *caché*. Por
ejemplo, si tenemos servidores web locales no se acelerará su
funcionamiento usando la *caché* HTTP y se malgastaría memoria que
podría ser usada por elementos de servidores remotos. Si un dominio
está exento de la *caché*, cuando se reciba una petición con destino a dicho
dominio se ignorará la *caché* y se devolverán directamente los datos
recibidos desde el servidor sin almacenarlos.

Dichos dominios se definen bajo el encabezado :guilabel:`Excepciones a
la caché` que podemos encontrar en la sección :menuselection:`Proxy
HTTP --> General`.

Filtrado de contenidos web
==========================

eBox permite el filtrado de páginas web según su contenido.  Para que
el filtrado tenga lugar la política global o la particular de cada
objeto desde que se accede deberá ser de :guilabel:`Filtrar` o
:guilabel:`Autorizar y Filtrar`.

Con eBox se pueden definir múltiples perfiles de filtrado pero sólo
trataremos en esta sección el perfil por defecto, dejando la discusión
de múltiples perfiles para la sección :ref:`advanced-proxy-ref`. Para
configurar las opciones de filtrado, iremos a :menuselection:`Proxy
HTTP --> Perfiles de Filtrado` y seleccionaremos la configuración del
perfil *por defecto*

.. image:: images/proxy/proxy-filter-profiles-list.png
   :scale: 80
   :align: center


El filtrado de contenidos de la páginas *Web* se basa en diferentes
métodos incluyendo marcado de frases clave, filtrado heurístico y
otros filtros más sencillos. La conclusión final es determinar si una
página puede ser visitada o no.

El primer filtro es el anti-virus. Para poder utilizarlo debemos tener el
módulo de **antivirus** instalado y activado. Podemos configurar si deseamos
activarlo o no. Si está activado se bloqueará el tráfico HTTP en el que
sean detectados virus.

El filtro de contenidos principalmente consiste en el análisis de los
textos presentes en las paginas web, si se considera que el contenido
no es apropiado (pornografía, violencia, etc) se bloqueará el acceso a la
página.

Para controlar este proceso se puede establecer un umbral más o menos
restrictivo, siendo este el valor que se comparará con la puntuación
asignada a la página para decidir si se bloquea o no.  El lugar donde
establecer el umbral es la sección :guilabel:`Umbral de filtrado de
contenido`.  También se puede desactivar este filtro eligiendo el
valor :guilabel:`Desactivado`. Hay que tener en cuenta que con este
análisis se puede llegar a bloquear paginas inocuas, este problema se
puede remediar añadiendo dominios a una lista blanca, pero siempre
existirá el riesgo de un falso positivo con páginas desconocidas.

Existen otro tipo de filtros de carácter explícito:

* Por dominio: Prohibiendo el acceso a la página de un diario deportivo en una
  empresa.
* Por extensión del fichero a descargar.
* Por tipo de contenidos MIME: Denegando la descarga de todos los ficheros de audio o
  vídeo.

Estos filtros están dispuestos en la interfaz por medio de las
pestañas :guilabel:`Filtro de extensiones de fichero`,
:guilabel:`Filtro de tipos MIME` y :guilabel:`Filtro de dominios`,

.. image:: images/proxy/04-proxy-mime.png
   :scale: 80
   :align: center


En la pestaña de :guilabel:`Filtro de extensiones de fichero` se puede
seleccionar que extensiones serán bloqueadas.

De manera similar en :guilabel:`Filtro de tipos
MIME` se puede indicar qué tipos MIME se quieren bloquear y añadir
otros nuevos si es necesario.
Los tipos MIME (*Multipurpose Internet Mail Extensions*) son un
estándar, concebido para extender las capacidades del correo
electrónico, que define los tipos de contenidos. Estos también se usan
en otros protocolos como el HTTP para determinar el contenido de los
ficheros que se transmiten. Un ejemplo de tipo MIME es **text/html**
que son las páginas *Web*. El primero de los elementos determina el
tipo de contenido que almacena (texto, vídeo, audio, imagen, binario,
...) y el segundo el formato específico para representar dicho
contenido (HTML, MPEG, gzip, ...).

En la pestaña de :guilabel:`Filtro de dominios` encontraremos los parametros que
controlan el filtrado de paginas en base al dominio al que pertenecen. Existen dos opciones de carácter general:

* :guilabel:`Bloquear dominios especificados sólo como IP`, esta opción bloquea
  cualquier dominio especificado únicamente por su IP asegurándonos así que no es
  posible encontrar una manera de saltarse nuestras reglas mediante el
  uso de direcciones IP.
* :guilabel:`Bloquear dominios no listados`, esta opción bloquea todos los
  dominios que no estén presentes en la seccion :guilabel:`Reglas de dominios` o
  en las categorias presentes en  :guilabel:`Archivos de listas de dominios`. En
  este último caso, las categorias con una política de *Ignorar* no son
  consideradas como listadas.

A continuación tenemos, la lista de dominios, donde podemos introducir nombres de
dominio y seleccionar una política para ellos entre las siguientes:

Permitir siempre:
  El acceso a los contenidos del dominio será siempre permitido, todos los filtros
  del filtro de contenido son ignorados.

Denegar siempre:
  El acceso nunca se permitirá a los contenidos de este dominio.

Filtrar:
  Se aplicarán las reglas usuales a este dominio. Resulta útil
  si está activada la opción :guilabel:`Bloquear dominios no
  listados`.

.. image:: images/proxy/05-proxy-domains.png
   :align: center
   :scale: 80

En el encabezado :guilabel:`Archivos de listas de dominios` podemos simplificar
el trabajo del administrador usando listas clasificadas de
dominios. Estas listas son normalmente mantenidas por terceras partes y tienen la
ventaja de que los dominios están clasificados por categorías, permitiéndonos
seleccionar una política para una categoría entera de dominios.
eBox soporta las listas distribuidas por *urlblacklist* [#]_,
*shalla's blacklists* [#]_ y cualquiera que use el mismo formato.

.. [#] URLBlacklist: http://www.urlblacklist.com
.. [#] Shalla's blacklist: http://www.shallalist.de

Estas listas son distribuidas en forma de archivo comprimido. Una vez
descargado el archivo, podemos incorporarlo a nuestra configuración y
establecer políticas para las distintas categorías de dominios.

Las políticas que se pueden establecer en cada categoría son las
mismas que se pueden asignar a dominios y se aplican a todos los
dominios presentes en dicha categoría.  Existe una política adicional
:guilabel:`Ignorar` que, como su nombre indica, simplemente ignora la
existencia de la categoría a la hora de filtrar. Dicha política es la
elegida por defecto para todas las categorías.


.. image:: images/proxy/domain-list-categories.png
   :align: center
   :scale: 80

Ejemplo práctico
^^^^^^^^^^^^^^^^
Activar el modo transparente del *proxy*. Comprobar usando los comandos de
**iptables** las reglas de *NAT* que ha añadido eBox para activar este
modo

Para ello:

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del
   módulo` y activar el módulo :guilabel:`Proxy HTTP`, para ello
   marcar su casilla en la columna :guilabel:`Estado`.

   Efecto:
     eBox solicita permiso para sobreescribir algunos ficheros.

#. **Acción:**
   Leer los cambios de cada uno de los ficheros que van a ser modificados y
   otorgar permiso a eBox para sobreescribirlos.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Ir a :menuselection:`Proxy HTTP --> General`, activar
   la casilla de :guilabel:`Modo transparente`. Asegurarnos que eBox
   puede actuar como *router*, es decir, que haya al menos una interfaz de red
   externa y otra interna.

   Efecto:
     El **modo transparente** está configurado

#. **Acción:**
   :guilabel:`Guardar cambios` para confirmar la configuración

   Efecto:
     Se reiniciarán los servicios de cortafuegos y *proxy HTTP*.

#. **Acción:**
   Desde la consola en la máquina en la que está eBox, ejecutar el
   comando ``iptables -t nat -vL``.

   Efecto:
     La salida de dicho comando debe ser algo parecido a esto::

       Chain PREROUTING (policy ACCEPT 7289 packets, 1222K bytes)
        pkts bytes target     prot opt in    out     source     destination
         799 88715 premodules  all  -- any   any   anywhere    anywhere

       Chain POSTROUTING (policy ACCEPT 193 packets, 14492 bytes)
        pkts bytes target     prot opt in    out     source    destination
          29  2321 postmodules all  -- any   any   anywhere    anywhere
           0     0 SNAT        all  -- any   eth2  !10.1.1.1   anywhere to:10.1.1.1

       Chain OUTPUT (policy ACCEPT 5702 packets, 291K bytes)
        pkts bytes target     prot opt in    out     source    destination

       Chain postmodules (1 references)
        pkts bytes target     prot opt in    out     source    destination

       Chain premodules (1 references)
        pkts bytes target     prot opt in    out    source     destination
           0     0 REDIRECT   tcp  --  eth3  any   anywhere !192.168.45.204    tcp dpt:www redir ports 3129

.. include:: proxy-exercises.rst
