.. _web-section-ref:

Servicio de publicación de información web (HTTP)
*************************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Víctor Jiménez <vjimenez@warp.es>

La *Web* es uno de los servicios más comunes en Internet, tanto que se ha
convertido en su cara visible para la mayoría de los usuarios.

Una página *Web* empezó siendo la manera más cómoda de publicar información en
una red. Para acceder basta con un navegador *Web*, que se encuentra instalado
de serie en las plataformas de escritorio actuales. Una página *Web* es fácil
de crear y se puede visualizar desde cualquier ordenador.

Con el tiempo las posibilidades de las interfaces *Web* han mejorado y
ahora disponemos de verdaderas aplicaciones que no tienen nada que envidiar a
las de escritorio.

En este capítulo veremos una introducción al funcionamiento interno de la *Web*,
así como la configuración de un servidor *Web* con eBox.

Hyper Text Transfer Protocol
============================

Una de las claves del éxito de la *Web* ha sido el protocolo de capa
de Aplicación empleado, **HTTP** (*Hyper Text Transfer Protocol*), y es
que HTTP es muy sencillo a la vez que flexible.

HTTP es un protocolo orientado a peticiones y respuestas. Un cliente, también
llamado *User Agent*, realiza una solicitud a un servidor. El servidor la
procesa y devuelve una respuesta.

.. figure:: images/web/http.png
   :alt: Esquema de solicitud con cabeceras GET entre un cliente, y la
         respuesta 200 OK del servidor. Encaminadores y *proxies* en medio.

   Esquema de solicitud con cabeceras GET entre un cliente, y la
   respuesta 200 OK del servidor. Encaminadores y *proxies* en medio.

Por defecto HTTP usa el puerto TCP 80 para conexiones sin cifrar, y el 443 para
conexiones cifradas (HTTPS). Una de las tecnologías más usadas para el cifrado
es TLS [#]_.

.. [#] TLS (*Transport Layer Security*) y su predecesor SSL (*Secure
       Sockets Layer*) son protocolos de cifrado que aportan seguridad
       e integridad de datos para las comunicaciones en Internet. En
       la sección :ref:`vpn-ref` se ahondará en el tema.

Una solicitud del cliente contiene los siguientes elementos:

* Una primera línea conteniendo *<método> <recurso solicitado> <versión HTTP>*.
  Por ejemplo *GET /index.html HTTP/1.1* solicita el recurso */index.html*
  mediante GET y usando el protocolo HTTP/1.1.
* Cabeceras, como *User-Agent: Mozilla/5.0 ... Firefox/3.0.6* que identifican el
  tipo de cliente que solicita la información.
* Una línea en blanco.
* Un cuerpo del mensaje opcional. Se utiliza, por ejemplo, para enviar ficheros
  al servidor usando el método POST.

Hay varios métodos [#]_ con los que el cliente puede pedir información. Los más
comunes son GET y POST:

.. [#] Una explicación más detallada se puede encontrar en la sección 9 del
       :RFC:`2616`

GET:
  Se utiliza GET para solicitar un recurso. Es un método inocuo para el
  servidor, ya que no se debe modificar ningún fichero en el servidor
  si se hace una solicitud mediante GET.

POST:
  Se utiliza POST para enviar una información que debe procesar el servidor.
  Por ejemplo en un *webmail* cuando pulsamos *Enviar Mensaje*, se envía al
  servidor la información del correo electrónico a enviar. El servidor debe
  procesar esa información y enviar el correo electrónico.

OPTIONS:
  Sirve para solicitar qué métodos se pueden emplear sobre un recurso.

HEAD:
  Solicita información igual que **GET**, pero la respuesta no
  incluirá el cuerpo, sólo la cabecera. De esta forma se puede obtener
  la meta-información del recurso sin descargarlo.

PUT:
  Solicita que la información del cuerpo sea almacenada y accesible desde la
  ruta indicada.

DELETE:
  Solicita la eliminación del recurso indicado

TRACE:
  Indica al servidor que debe devolver la cabecera que envía el cliente.
  Es útil para ver cómo modifican la solicitud los *proxies* intermedios.

CONNECT:
  La especificación se reserva este método para realizar túneles.

La respuesta del servidor tiene la misma estructura que la solicitud
del cliente cambiando la primera fila. En este caso la primera fila
sigue la forma *<status code> <text reason>*, que corresponden al código de
respuesta y a un texto con la explicación respectivamente.

Los códigos de respuesta [#]_ más comunes son:

.. [#] En la sección 10 del :RFC:`2616` se pueden encontrar el listado
       completo de códigos de respuesta del servidor HTTP.

200 OK:
  La solicitud ha sido procesada correctamente.
403 Forbidden:
  Cuando el cliente se ha autenticado pero no tiene permisos para
  operar con el recurso solicitado.
404 Not Found:
  Si el recurso solicitado no se ha encontrado.
500 Internal Server Error:
  Si ha ocurrido un error en el servidor que ha impedido la correcta ejecución
  de la solicitud.

HTTP tiene algunas **limitaciones** dada su simplicidad. Es un
protocolo sin estado, por tanto el servidor no puede recordar a los
clientes entre conexiones. Una solución para este problema es el uso de
*cookies*. Por otro lado, el servidor no puede iniciar una
conversación con el cliente. Si el cliente quiere alguna notificación
del servidor, deberá solicitarla periódicamente.

El servicio HTTP puede ofrecer dinámicamente los
resultados de aplicaciones *software*. Para ello, el cliente realiza una
petición a una determinada URL con unos parámetros y el *software* se encarga
gestionar la petición para devolver un resultado. El primer método utilizado fue
conocido como CGI (*Common Gateway Interface*) que se ejecuta un
comando por URL. Este mecanismo ha sido superado
debido a su sobrecarga en memoria y bajo rendimiento por otras
soluciones:

*FastCGI*:
  Un protocolo de comunicación entre las aplicaciones
  *software* y el servidor HTTP, teniendo un único proceso para
  resolver las peticiones realizadas por el servidor HTTP.
SCGI (*Simple Common Gateway Interface*):
  Es una versión simplificada del protocolo de *FastCGI*
Otros mecanismos de expansión:
  Estos mecanismos dependerán del servidor HTTP utilizado y pueden permitir
  la ejecución de *software* dentro del propio servidor.


El servidor HTTP Apache
=======================

El **servidor HTTP Apache** [#]_ es el programa más popular para
servir páginas *Web* desde abril de 1996. EBox usa dicho servidor
tanto para su interfaz *Web* de administración como para el módulo *Web*.
Su objetivo es ofrecer un sistema seguro, eficiente y extensible siguiendo
los estándares HTTP. Ofrece la posibilidad de extender las funcionalidades
del núcleo (*core*), utilizando módulos adicionales para incluir nuevas
características. Es decir, una de sus principales ventajas es la
extensibilidad.

.. [#] Apache HTTP Server project http://httpd.apache.org.

Algunos de los módulos nos ofrecen interfaces para lenguajes de *script*.
Ejemplos de ello son *mod_perl*, *mod_python*, *TCL* ó *PHP*, lo que
permite crear páginas *Web* usando los lenguajes de programación Perl,
Python, TCL o PHP. También tenemos módulos para varios sistemas de
autenticación como *mod_access*, *mod_auth*, entre otros. Además,
permite el uso de SSL y TLS con *mod_ssl*, módulo de proxy con
*mod_proxy* o un potente sistema de reescritura de URL con
*mod_rewrite*. En definitiva, disponemos de una gran cantidad de módulos
de Apache [#]_ para añadir diversas funcionalidades.

.. [#] Podemos consultar la lista completa en http://modules.apache.org.

.. _vhost-ref:

Dominios virtuales
==================

El objetivo de los **dominios virtuales** (*Virtual Hosts*) es alojar varios
sitios *Web* en un mismo servidor.

Si el servidor dispone de una dirección IP pública por cada sitio *Web*,
se puede realizar una configuración por cada interfaz de red. Vistos desde
fuera dará la impresión de que son varios *Hosts* en la misma red. El servidor
redirigirá el tráfico de cada interfaz a su sitio *Web* correspondiente.

Sin embargo, lo más normal es disponer de una o dos IPs por máquina. En ese
caso habrá que asociar cada sitio *Web* con su dominio. El servidor *Web*
leerá las cabeceras de los clientes y dependiendo del dominio de la solicitud
lo redirigirá a un sitio *Web* u otro. A cada una de estas configuraciones se
le llama *Virtual Host*, ya que sólo hay un *Host* en la red, pero se simula
que existen varios.

Configuración de un servidor HTTP con eBox
===========================================

A través del menú :menuselection:`Web` podemos acceder a la configuración
del servicio.

.. figure:: images/web/02-webserver.png
   :scale: 70
   :align: center
   :alt: Aspecto de la configuración del módulo **Web**

   Aspecto de la configuración del módulo **Web**

En el primer formulario podemos modificar los siguientes parámetros:

Puerto de escucha
  Dónde va a escuchar peticiones HTTP el demonio.

Habilitar el *public_html* por usuario
  Con esta opción, si está habilitado el módulo **Samba**
  (:ref:`ebox-samba-ref`) los usuarios pueden crear un subdirectorio
  llamado *public_html* en su directorio personal dentro de **samba**
  que será expuesto por el servidor *Web* a través de la URL
  *http://<eboxIP>/~<username>/* donde *username* es el nombre del
  usuario que quiere publicar contenido.

Respecto a los :ref:`vhost-ref`, simplemente se introducirá el
nombre que se desea para el dominio y si está habilitado o no. Cuando
se crea un nuevo dominio, se trata de crear una entrada en el módulo
**DNS** (si está instalado) de tal manera que si se añade el dominio
*www.company.com*, se creará el dominio *company.com* con el nombre de
máquina *www* cuya dirección IP será la dirección de la primera
interfaz de red que sea estática.

Para publicar datos estos deben estar bajo */var/www/<vHostname>*,
donde *vHostName* es el nombre del dominio virtual. Si se quiere añadir
cualquier configuración personalizada, por ejemplo capacidad para
servir aplicaciones en Python usando *mod_python*, se deberán crear los
ficheros de configuración necesarios para ese dominio virtual en el
directorio */etc/apache2/sites-available/user-ebox-<vHostName>/*.

Ejemplo práctico
^^^^^^^^^^^^^^^^
Habilitar el servicio *Web*. Comprobar que está escuchando en el puerto 80.
Configurarlo para que escuche en un puerto distinto y comprobar que el
cambio surte efecto.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activa el módulo :guilabel:`servidor web`, para ello marcar su casilla en la
   columna :guilabel:`Estado`. Nos informa de los cambios que va a realizar
   en el sistema. Permitir la operación pulsando el botón
   :guilabel:`Aceptar`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     El servidor *Web* ha quedado habilitado por defecto en el puerto 80.

#. **Acción:**
   Utilizando un navegador, acceder a la siguiente dirección
   `http://ip_de_eBox/`.

   Efecto:
     Aparecerá una página por defecto de **Apache** con el mensaje *'It
     works!'*.

#. **Acción:**
   Acceder al menú :menuselection:`Web`. Cambiar el valor del puerto de 80 a
   1234 y pulsar el botón :guilabel:`Cambiar`.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     Ahora el servidor *Web* está escuchando en el puerto 1234.

#. **Acción:**
   Volver a intentar acceder con el navegador a `http://<ip_de_eBox>/`.

   Efecto:
     No obtenemos respuesta y pasado un tiempo el navegador informará de que
     ha sido imposible conectar al servidor.

#. **Acción:**
   Intentar acceder ahora a `http://<ip_de_eBox>:1234/`.

   Efecto:
     El servidor responde y obtenemos la página de *'It works!'*.

.. include:: web-exercises.rst
