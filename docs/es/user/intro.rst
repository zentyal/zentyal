####################################################
 eBox Platform: servidor unificado de red para PYMEs
####################################################

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Isaac Clerencia <iclerencia@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Víctor Jímenez <vjimenez@warp.es>,
                   Jorge Salamero <jsalamero@ebox-platform.com>,
                   Javier Uruen <juruen@ebox-platform.com>,

Presentación
************

**eBox Platform** (<http://ebox-platform.com/>) es un servidor unificado de
red que ofrece una administración sencilla y eficiente de
las redes de ordenadores para la pequeña y mediana empresa
(PYME). Puede actuar gestionando la infraestructura de red, como puerta de enlace a Internet,
gestionando las amenazas de seguridad (UTM) [#]_, como servidor de oficina, como
servidor de comunicaciones o una combinación de estas. Este
manual está escrito para la versión |version| de eBox Platform.

.. [#] **UTM** (*Unified Threat Management*): Término que agrupa una
       serie de funcionalidades relacionadas con la seguridad de las
       redes informáticas: cortafuegos, detección de intrusos, antivirus, etc.

Todas estas funcionalidades están profundamente integradas,
automatizando la mayoría de tareas, evitando errores y ahorrando tiempo para el
administrador de sistemas. Esta amplia gama de servicios de
red son administrados a través de una cómoda e intuitiva interfaz web.
eBox Platform tiene un diseño modular pensado para poder ser extendido
fácilmente, pudiendo instalar sólamente los módulos que se necesiten en
cada servidor. Además está publicado bajo una licencia de Software Libre (GPL) [#f1]_. Sus
principales características son:

.. [#f1] **GPL** (*GNU General Public License*): Licencia de software que
         permite la libertad de redistribución, adaptación, uso y creación de
         obras derivadas con la misma licencia.

* Gestión unificada y eficiente de los servicios:

  * Automatización de tareas.
  * Integración de servicios.

* Interfaz cómoda e intuitiva.
* Extensible y adaptable a necesidades específicas.
* Independiente del hardware.
* Software Libre.

Los servicios que actualmente ofrece son:

* **Gestión de redes:**

  * Cortafuegos y encaminador

    * Filtrado de tráfico
    * NAT y redirección de puertos
    * Redes locales virtuales (VLAN 802.1Q)
    * Soporte para múltiples puertas de enlace, balanceo de carga y
      auto-adaptación ante la pérdida de conectividad.
    * Moldeado de tráfico (soportando filtrado a nivel de aplicación)
    * Monitorización de tráfico
    * Soporte de DNS dinámico

  * Objetos y servicios de red de alto nivel

  * Infraestructura de red

    * Servidor DHCP
    * Servidor DNS
    * Servidor NTP

  * Redes privadas virtuales (VPN)

    * Auto-configuración dinámica de rutas

  * Proxy HTTP

    * Caché
    * Autenticación de usuarios
    * Filtrado de contenido (con listas categorizadas)
    * Antivirus transparente

  * Servidor de correo

    * Filtro de Spam y Antivirus
    * Filtro transparente de POP3
    * Listas blancas, negras y grises

  * Servidor web

    * Dominios virtuales

  * Sistema de Detección de Intrusos (IDS)
  * Autoridad de Certificación


* **Trabajo en grupo:**

  * Directorio compartido usando LDAP (Windows/Linux/Mac)

    * Autenticación compartida (incluyendo PDC de Windows)

  * Almacenamiento compartido actuando como NAS (almacenamiento pegado a la
    red)
  * Impresoras compartidas
  * Servidor de *Groupware*: calendarios, agendas, ...
  * Servidor de VozIP

    * Buzón de voz
    * Conferencias
    * Llamadas a través de proveedor externo
  * Servidor de mensajería instantánea (Jabber/XMPP)

    * Conferencias
  * Rincón del usuario para que estos puedan modificar sus datos

* **Informes y monitorización**

  * *Dashboard* para tener la información de los servicios centralizada
  * Monitorización de disco, memoria, carga, temperatura y CPU de la máquina
  * Estado del RAID por software e información del uso de disco duro
  * Registros de los servicios de red en BBDD, permitiendo la
    realización de informes diarios, semanales, mensuales y anuales
  * Sistema de monitorización a través de eventos

    * Notificación vía Jabber, correo y subscripción de noticias (RSS)

* **Gestión de la máquina:**

  * Copia de seguridad de configuración y datos
  * Actualizaciones

  * Centro de control para administrar y monitorizar fácilmente varias máquinas
    eBox desde un único punto [#]_

.. [#] Para más información sobre este servicio ir a
       http://www.ebox-technologies.com/products/controlcenter/
       empresa encargada del desarrollo de eBox Platform.

Instalación
***********

eBox Platform está pensada para su instalación en una máquina
(real o virtual) de forma, en principio, exclusiva. Esto no impide que se puedan
instalar otros servicios no gestionados a través de la interfaz que deberán ser
configurados manualmente.

Funciona sobre el sistema operativo *GNU/Linux* con la distribución
*Ubuntu Server Edition* [#]_ versión estable *Long Term Support* (LTS)
[#]_.  La instalación puede realizarse de dos maneras diferentes:

.. [#] *Ubuntu* es una distribución de *GNU/Linux*
       desarrollada por *Canonical* y la comunidad orientada a ordenadores
       portátiles, sobremesa y servidores <http://www.ubuntu.com/>.

.. manual

.. [#] En el ":ref:`ubuntu-console-ref`" en la sección
       ":ref:`ubuntu-version-ref`" existe una breve
       descripción sobre la publicación de versiones de *Ubuntu*.

* Usando el instalador de eBox Platform (opción recomendada).
* A partir de una instalación de *Ubuntu Server
  Edition* existente. En el ":ref:`ubuntu-console-ref`" existe una
  explicación del proceso de instalación de *Ubuntu*.

En el segundo caso es necesario añadir los repositorios oficiales
de eBox Platform y proceder a instalar tal como se explica en el
:ref:`ebox-install-ref` del ":ref:`ubuntu-console-ref`".

.. endmanual

.. web

.. [#] Cuyo soporte es mayor que en una versión normal y para la
       versión para servidores llega a los 5 años.

* Usando el instalador de eBox Platform (opción recomendada).
* Instalando a partir de una instalación de *Ubuntu Server
  Edition*.

En el segundo caso es necesario añadir los repositorios oficiales
de eBox Platform y proceder a instalar eBox con aquellos paquetes que
se deseen.

.. endweb

Sin embargo, en el primer caso se facilita la instalación y
despliegue de eBox Platform ya que se encuentran todas las dependencias
en un sólo CD y además se realizan algunas preconfiguraciones durante el
proceso de instalación.

El instalador de eBox Platform
==============================

El instalador de eBox Platform está basado en el instalador de *Ubuntu* así
que el proceso de instalación resultará muy familiar a quien ya lo conozca.

.. figure:: images/intro/eBox-installer.png
   :scale: 50
   :alt: Pantalla de inicio del instalador
   :align: center

   Pantalla de inicio del instalador

Tras instalar el sistema base y reiniciar, comenzará la
instalación de eBox Platform. Existen dos métodos para la selección de
funcionalidades a incluir en nuestro sistema.

.. figure:: images/intro/package-selection-method.png
   :scale: 50
   :alt: Selección del método de instalación
   :align: center

   Selección del método de instalación

Simple:
  Se instalarán un conjunto de paquetes que agrupan una serie de
  funcionalidades según la tarea que vaya a desempeñar el servidor.
Avanzado:
  Se seleccionarán los paquetes de manera individualizada. Si
  algún paquete tiene como dependencia otro, posteriormente se
  seleccionará automáticamente.

Si la selección es simple, aparecerá la lista de perfiles
disponibles. Como se puede observar en la figura
:ref:`profiles-img-ref` dicha lista concuerda con los apartados
siguientes de este manual.

.. _profiles-img-ref:

.. figure:: images/intro/profiles.png
   :scale: 50
   :alt: Selección de perfiles
   :align: center

   Selección de perfiles

:ref:`ebox-gateway-ref`:
   eBox es la puerta de enlace de la red local ofreciendo un acceso
   a Internet seguro y controlado.
:ref:`ebox-utm-ref`:
   eBox protege la red local contra ataques externos, intrusiones,
   amenazas en la seguridad interna y posibilita la interconexión
   segura entre redes locales a través de Internet u otra red externa.
:ref:`ebox-infrastructure-ref`:
   eBox gestiona la infraestructura de la red local con los servicios
   básicos: DHCP, DNS, NTP, servidor HTTP, etc.
:ref:`ebox-office-ref`:
   eBox es el servidor de recursos compartidos de la red local: ficheros,
   impresoras, calendarios y contactos, autenticación y perfiles de
   usuarios y grupos, etc.
:ref:`ebox-comm-ref`:
   eBox se convierte en el centro de comunicaciones de
   tu organización incluyendo el correo, mensajería instántanea y voz
   sobre IP.

Podemos seleccionar varios perfiles para combinar sus funcionalidades.
Además la selección no es definitiva, pudiendo posteriormente instalar y
desinstalar paquetes según se necesite.

Sin embargo, si el método seleccionado es avanzado, entonces aparecerá
la larga lista de módulos de eBox Platform y se podrán seleccionar
individualmente aquellos que se necesiten. Al terminar la selección,
es posible que se instalen también paquetes del resto ya que
dependencias de alguno de los seleccionados.

.. figure:: images/intro/module-selection.png
   :scale: 70
   :alt: Selección de módulos
   :align: center

   Selección de módulos

Una vez seleccionados los componentes a instalar, comenzará la
instalación que irá informando de su estado con una barra de progreso:

.. figure:: images/intro/installing-eBox.png
   :scale: 70
   :alt: Instalando eBox Platform
   :align: center

   Instalando eBox Platform

Tras la instalación, se pide la contraseña para acceder a la interfaz web de
administración de eBox Platform:

.. image:: images/intro/password.png
   :scale: 70
   :alt: Introducir contraseña de acceso a la interfaz web
   :align: center

Se tiene que confirmar la contraseña anterior:

.. image:: images/intro/repassword.png
   :scale: 70
   :alt: Confirmar contraseña de acceso a la interfaz web
   :align: center

El instalador tratará de preconfigurar algunos parámetros
importantes dentro de la configuración. En primer lugar, si alguna de las
interfaces de red es externa a la red local, es decir, si va a ser utilizada
para conectarse a Internet. Se aplicarán políticas estrictas para todo el
tráfico entrante a través de interfaces de red externas. Puede no haber
ninguna interfaz externa dependiendo del papel que desempeñe servidor.

.. figure:: images/intro/select-external-iface.png
   :scale: 70
   :alt: Selección de la interfaz de red externa
   :align: center

   Selección de la interfaz de red externa

En segundo lugar, si se ha instalado el módulo de correo, se
solicitará que se introduzca el dominio virtual por defecto que será
el principal del sistema.

.. figure:: images/intro/vmaildomain.png
   :scale: 70
   :alt: Dominio virtual de correo principal
   :align: center

   Dominio virtual de correo principal

Una vez hayan sido respondidas estas preguntas, se realizará la
preconfiguración de cada uno de los módulos instalados preparados para
su utilización desde la interfaz web.

.. figure:: images/intro/preconfiguring-ebox.png
   :scale: 50
   :alt: Progreso de la configuración
   :align: center

   Progreso de la configuración

Una vez terminado este proceso, aparecerá un mensaje informando como
conectarse a la interfaz web de eBox Platform.

.. figure:: images/intro/ebox-ready-to-use.png
   :scale: 50
   :alt: Instalación finalizada
   :align: center

   Instalación finalizada

El proceso de instalación de eBox Platform ha finalizado y aparecerá
la consola del sistema donde podremos autenticarnos con el usuario
creado durante la instalación de *Ubuntu*. La contraseña de eBox
Platform es exclusiva de la interfaz web y no tiene nada que ver con
la de este usuario administrador de la máquina. Al iniciar sesión en la consola,
se ofrece un mensaje informativo específico de eBox Platform como el
que aparece en la imagen.

.. image:: images/intro/motd.png
   :scale: 50
   :align: center
   :alt: Mensaje de entrada a la consola

La interfaz web de administración
*********************************

Una vez instalado eBox Platform, la dirección para acceder a la
interfaz web de administración es:

  https://direccion_de_red/ebox/

Donde *direccion_de_red* es la dirección IP o el nombre de la máquina donde está
instalado eBox que resuelve a esa dirección.

Para acceder a la interfaz web se debe usar Mozilla Firefox, ya que
otros navegadores como Microsoft Internet Explorer pueden dar problemas.

La primera pantalla solicita la contraseña del administrador:

.. image:: images/intro/01-login.png
   :scale: 50
   :alt: Entrada a la interfaz
   :align: center

Tras autenticarse aparece la interfaz de administración que se encuentra dividida en
tres partes fundamentales:

.. figure:: images/intro/02-homepage.png
   :scale: 50
   :alt: Pantalla principal
   :align: center

   Pantalla principal

Menú lateral izquierdo:
  Contiene los enlaces a todos los **servicios** que se pueden configurar
  mediante eBox Platform, separados por categorías. Cuando se ha seleccionado
  algún servicio en este menú puede aparecer un submenú para configurar
  cuestiones particulares de dicho servicio.

  .. figure:: images/intro/03-sidebar.png
     :scale: 50
     :alt: Menú lateral izquierdo
     :align: center

     Menú lateral izquierdo

Menú superior:
  Contiene las **acciones** para guardar los cambios realizados en el
  contenido y hacerlos efectivos, así como para el cierre de sesión.

  .. figure:: images/intro/04-topbar.png
     :alt: Menú superior
     :align: center

     Menú superior

Contenido principal:
  El contenido, que ocupa la parte central, comprende uno o varios formularios o
  tablas con información acerca de la **configuración del servicio**
  seleccionado a través del menú lateral izquierdo y sus submenús. En
  ocasiones, en la parte superior, aparecerá una barra de pestañas en la que
  cada pestaña representará una subsección diferente dentro de la sección a la
  que hemos accedido.

  .. figure:: images/intro/05-center-configure.png
     :scale: 50
     :alt: Formulario de configuración
     :align: center

     Formulario de configuración

*Dashboard*:
  El *dashboard* es la pantalla inicial de la interfaz. Contiene una serie de *widgets*
  configurables. En todo momento se pueden reorganizar pulsando en los títulos y
  arrastrándolos.

  .. figure:: images/intro/05-center-dashboard.png
     :scale: 70
     :alt: *Dashboard*
     :align: center

     *Dashboard*

  Pulsando en :guilabel:`Configurar Widgets` la interfaz cambia, permitiendo retirar
  y añadir nuevos *widgets*. Para añadir uno nuevo, se busca en el menú
  superior y se arrastra a la parte central.

  .. figure:: images/intro/05-center-dashboard-configure.png
     :scale: 90
     :alt: Configuración del *dashboard*
     :align: center

     Configuración del *dashboard*

Una particularidad importante del funcionamiento de eBox Platform es su forma
de hacer efectivas las configuraciones que hagamos en la interfaz. Para ello, primero
se tendrán que aceptar los cambios en el formulario actual, pero para
que estos cambios sean efectivos y se apliquen de forma permanente se
tendrá que presionar :guilabel:`Guardar Cambios` del menú
superior. Este botón cambiará a color rojo para indicarnos que hay
cambios sin guardar. Si no se sigue este procedimiento se perderán
todos los cambios que se hayan realizado a lo largo de la sesión al
finalizar ésta. Existen algunos casos especiales en los que no es
necesario guardar los cambios pero se avisa adecuadamente.

.. figure:: images/intro/06-savechanges.png
   :scale: 70
   :alt: Guardar Cambios
   :align: center

   Guardar Cambios

¿Cómo funciona eBox Platform?
*****************************

EBox Platform no es sólo una interfaz web que sirve para administrar
los servicios de red más comunes [#]_. Entre sus principales funciones
destaca el dar cohesión y unicidad a un conjunto de servicios de red
que de lo contrario funcionarían de forma independiente.

.. [#] Para mostrar la magnitud del proyecto, podemos consultar el
       sitio independiente **ohloh.net**, donde se hace un análisis
       extenso al código de eBox Platform en
       <http://www.ohloh.net/p/ebox/analyses/latest>.

.. figure:: images/intro/integration.png
   :scale: 70
   :alt: Integración de eBox Platform
   :align: center

Toda la configuración de cada uno de los servicios es escrita por eBox
de manera automática. Para ello utiliza un sistema de plantillas.
Con esta automatización se evitan los posibles errores cometidos de forma
manual y ahorra a los administradores el tener que conocer los
detalles de cada uno de los formatos de los ficheros de configuración
de cada servicio. Por tanto, no se deben editar los ficheros de
configuración originales del sistema ya que se sobreescribirían al
guardar cambios al estar gestionados automáticamente por eBox.

.. manual

En el apartado :ref:`ebox-internals-ref` existe una explicación más extensa acerca
del funcionamiento interno.

.. endmanual

Los informes de los eventos y posibles errores de eBox se
almacenan en el directorio `/var/log/ebox/` y se distribuyen en los
siguientes ficheros:

`/var/log/ebox/ebox.log`:
  Los errores relacionados con eBox Platform.
`/var/log/ebox/error.log`:
  Los errores relacionados con el servidor web de la interfaz.
`/var/log/ebox/access.log`:
  Los accesos al servidor web de la interfaz.

Si se quiere aumentar la información sobre algún error que se haya
producido, se puede habilitar el modo de depuración de errores a través
de la opción *debug* en el fichero `/etc/ebox/99ebox.conf`. Tras
habilitar esta opción se deberá reiniciar el servidor web de la
interfaz mediante `sudo /etc/init.d/ebox apache restart`.

Emplazamiento en la red
***********************

Configuración de la red local
=============================

eBox Platform puede utilizarse de dos maneras fundamentales:

* **Encaminador** y **filtro** de la conexión a internet.
* Servidor de los distintos servicios de red.

Ambas funcionalidades pueden combinars en una misma máquina o
separarse en varias.

La figura :ref:`ebox-net-img-ref` escenifica las distintas ubicaciones que
puede tomar el servidor con eBox Platform dentro de la red, tanto
haciendo nexo de unión entre redes como un servidor dentro de la
propia red.

.. _ebox-net-img-ref:

.. figure:: images/intro/multiple.png
   :scale: 60
   :alt: Distintas ubicaciones en la red
   :align: center

   Distintas ubicaciones en la red

A lo largo de esta documentación se verá cómo configurar eBox Platform para
desempeñar un papel de puerta de enlace y encaminador. Y por supuesto también
veremos la configuración en los casos que actúe como un servidor más dentro de
la red.

Configuración de red con eBox Platform
======================================

Si colocamos el servidor en el interior de una red, lo más probable es que se nos
asigne una dirección IP a través del protocolo DHCP. A través de
:menuselection:`Red --> Interfaces` se puede acceder a cada una de las tarjetas de
red detectadas por el sistema y se puede configurar de manera estática (dirección
configurada manualmente), dinámica (dirección configurada por DHCP) o como
*Trunk 802.1Q*, para la creación de redes VLAN.

.. figure:: images/intro/07-networkinterfaces.png
   :scale: 60
   :alt: Configuración de interfaces de red
   :align: center

   Configuración de interfaces de red

Si configuramos la interfaz como estática podemos asociar una o más
:guilabel:`Interfaces Virtuales` a dicha interfaz real para servir direcciones IP
adicionales con lo que se podría atender a diferentes redes o a la misma con diferente
dirección.

.. figure:: images/intro/08-networkstatic.png
   :scale: 60
   :alt: Configuración estática de interfaces de red
   :align: center

   Configuración estática de interfaces de red

Para que eBox sea capaz de resolver nombres de dominio debemos indicarle la dirección de uno
o varios servidores de nombres en :menuselection:`Red --> DNS`.

.. figure:: images/intro/09-dns.png
   :scale: 80
   :alt: Configuración de servidores DNS
   :align: center

   Configuración de servidores DNS

Diagnóstico de redes
====================

Para ver si hemos configurado bien nuestra red podemos utilizar las herramientas
de :menuselection:`Red --> Diagnóstico`.

.. figure:: images/intro/10-diagnotics.png
   :scale: 50
   :alt: Herramientas de diagnóstico de redes
   :align: center

   Herramientas de diagnóstico de redes

**ping** es una herramienta que utiliza el protocolo de diagnóstico de redes ICMP
para observar la conectividad hasta una máquina remota mediante una sencilla
conversación entre ambas.

.. figure:: images/intro/10-diagnotics-ping.png
   :scale: 80
   :alt: Herramienta ping
   :align: center

   Herramienta **ping**

Adicionalmente disponemos de la herramienta **traceroute** que se encarga
de trazar los paquetes encaminados a través de las distintas redes hasta
llegar a una máquina remota determinada. Con esta herramienta podemos ver
el camino que siguen los paquetes para diagnósticos más avanzados.

.. figure:: images/intro/10-diagnostics-trace.png
   :scale: 80
   :alt: Herramienta traceroute
   :align: center

   Herramienta **traceroute**

Y también contamos con la herramienta **dig** que se utiliza para comprobar
el correcto funcionamiento del servicio de resolución de nombres.

.. figure:: images/intro/10-diagnotics-dig.png
   :scale: 80
   :alt: Herramienta dig
   :align: center

   Herramienta **dig**


Ejemplo práctico A
------------------

Vamos a configurar eBox para que obtenga la configuración de la red mediante
DHCP.

Para ello:

#. **Acción:**
   Acceder a la interfaz de eBox, entrar en :menuselection:`Red --> Interfaces` y
   seleccionar para la interfaz de red *eth0* el Método *DHCP*.
   Pulsar el botón :guilabel:`Cambiar`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios` y la interfaz de red mantiene
     los datos introducidos.

#. **Acción:**
   Entrar en :menuselection:`Estado del módulo` y
   activar el módulo **Red**, para ello marcar su casilla en la columna
   :guilabel:`Estado`.

   Efecto:
     eBox solicita permiso para sobreescribir algunos ficheros.

#. **Acción:**
   Leer los cambios de cada uno de los ficheros que van a ser modificados y
   otorgar permiso a eBox para sobreescribirlos.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios` y algunos módulos que dependen
     de Network ahora pueden ser activados.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     Ahora eBox gestiona la configuración de la red.

#. **Acción:**
   Acceder a :menuselection:`Red --> Herramientas de
   Diagnóstico`. Hacer ping a ebox-platform.com.

   Efecto:
     Se muestran como resultado tres intentos satisfactorios de conexión con
     el servidor de internet.

#. **Acción:**
   Acceder a :menuselection:`Red --> Herramientas de
   Diagnóstico`. Hacer ping a una eBox de un compañero de aula.

   Efecto:
     Se muestran como resultado tres intentos satisfactorios de conexión con
     la máquina.

#. **Acción:**
   Acceder a :menuselection:`Red --> Herramientas Diagnóstico`. Ejecutar
   traceroute hacia ebox-technologies.com.

   Efecto:
     Se muestra como resultado la serie de máquinas que un paquete recorre
     hasta llegar a la máquina destino.

Ejemplo práctico B
------------------

Para el resto de ejercicios del manual es una buena práctica habilitar
los registros.

Para ello:

#. **Acción:**
   Acceder a la interfaz de eBox, entrar en :menuselection:`Estado del módulo` y
   activar el módulo **Registros**, para ello marcar su casilla en la columna
   :guilabel:`Estado`.

   Efecto:
     eBox solicita permiso para realizar una serie de acciones.

#. **Acción:**
   Leer los acciones que va a realizar eBox y aceptarlas.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     Ahora eBox tiene los registros activados. Puedes echar un vistazo
     en :menuselection:`Registros --> Consultar registros`. De todas
     maneras, en la sección :ref:`logs-ref`.
