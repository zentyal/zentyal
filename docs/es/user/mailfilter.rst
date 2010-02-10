.. _mailfilter-sec-ref:

Filtrado de correo electrónico
******************************

.. sectionauthor:: Jose A. Calvo <jacalvo@ebox-platform.com>
                   Enrique J. Hernandez <ejhernandez@ebox-platform.com>
                   Víctor Jímenez <vjimenez@warp.es>

Los principales problemas en el sistema de correo electrónico son el
*spam* y los virus.

El **spam**, o correo electrónico no deseado, distrae la atención del usuario
que tiene que bucear en su bandeja de entrada para encontrar los correos
legítimos. También genera una gran cantidad de tráfico que puede afectar al
funcionamiento normal de la red y del servicio de correo.

Aunque los **virus informáticos** no afectan al sistema en el que está instalado
eBox, un correo electrónico que contenga un virus puede infectar otras máquinas
clientes de la red.

Esquema del filtrado de correo de eBox
======================================

Para defendernos de estas amenazas, eBox dispone de un filtrado de
correo bastante potente y flexible.

.. figure:: images/mailfilter/mailfilter-schema.png
   :scale: 80
   :alt: Esquema del filtrado de correo en eBox

   *GRAPHIC: Esquema del filtrado de correo en eBox*

En la figura se observan los diferentes pasos que sigue un correo antes
de determinar si es válido o no. En primer lugar, el servidor
de correo envía el correo al gestor de políticas de listas grises. Si
el correo supera este filtro, pasará al filtro de correo donde se
examinarán una serie de características del correo, para ver si contiene virus
o si se trata de correo basura, utilizando para ello un filtro estadístico.
Si supera todos esos filtros, entonces se determina que el correo es válido y se
emite a su receptor o se almacena en un buzón del servidor.

En esta sección vamos a explicar paso a paso en qué consiste cada uno
de estos filtros y cómo se configuran en eBox.

Lista gris
-----------

Una **greylist** (lista gris) [#]_ es un método de defensa contra el *spam*
que no descarta correos, sólo le pone más difícil el trabajo a un
servidor de correo que actúa como *spammer* (emisor de correo *spam* o
basura).

.. [#] eBox usa **postgrey** http://postgrey.schweikert.ch/ como
   gestor de esta política en **postfix**.

En el caso de eBox, la estrategia utilizada es fingir estar fuera de servicio.
Cuando un servidor nuevo quiere enviarle un correo, eBox le dice "*Estoy fuera
de servicio en este momento, inténtalo en 300 segundos.*" [#]_, si el servidor
remitente cumple la especificación reenviará el correo pasado ese tiempo y eBox
lo apuntará como un servidor correcto.

En eBox la lista gris exime al correo enviado desde redes internas, al enviado
desde objetos con política de permitir retransmisión y al que tiene como
remitente una dirección que se encuentra en la lista blanca del antispam.

.. [#] Realmente el servidor de correo envía como respuesta
   *Greylisted*, es decir, puesto en la lista gris en espera de
   permitir el envío de correo o no pasado el tiempo configurado.

Sin embargo, los servidores que envían *Spam* no suelen seguir el estándar y
no reenviarán el correo. Así habríamos evitado los mensajes de *Spam*.

.. figure:: images/mailfilter/greylisting-schema.png
   :scale: 80
   :alt: Esquema del funcionamiento de una lista gris

   *GRAPHIC: Esquema del funcionamiento de una lista gris*


El *Greylist* se configura desde :menuselection:`Correo --> Lista gris`
con las siguientes opciones:

.. image:: images/mailfilter/05-greylist.png
   :scale: 70

Habilitado:
  Marcar para activar el *greylisting*.

Duración de la lista gris (segundos):
  Segundos que debe esperar el servidor remitente antes de reenviar el correo.

Ventana de reintento (minutos):
  Tiempo en horas en el que el servidor remitente puede enviar
  correos. Si el servidor ha enviado algún correo durante ese tiempo,
  dicho servidor pasará a la lista gris. En una lista gris, el
  servidor de correo puede enviar todos los correos que quiera sin
  restricciones temporales.

Tiempo de vida de las entradas (días):
  Días que se almacenarán los datos de los servidores evaluados en la
  lista gris. Si pasan más de los días configurados, cuando el
  servidor quiera volver a enviar correos tendrá que pasar de nuevo por
  el proceso de *greylisting* descrito anteriormente.

Verificadores de contenidos
---------------------------

El filtrado de contenido del correo corre a cargo de los **antivirus**
y de los detectores de **spam**. Para realizar esta tarea eBox usa un
interfaz entre el MTA (**postfix**) y dichos programas. Para ello, se
usa el programa **amavisd-new** [#]_ que habla con el MTA usando
(E)SMTP o LMTP (*Local Mail Transfer Protocol* :RFC:`2033`) para comprobar
que el correo no es *spam* ni contiene virus. Adicionalmente, esta interfaz
realiza las siguientes comprobaciones:

 - Listas blancas y negras de ficheros y extensiones.
 - Filtrado de correos con cabeceras mal-formadas.

.. [#] **Amavisd-new**: http://www.ijs.si/software/amavisd/

Antivirus
---------

El *antivirus* que usa eBox es **ClamAV** [#]_, el cual es un
conjunto de herramientas *antivirus* para UNIX especialmente diseñadas
para escanear adjuntos en los correos electrónicos en un
MTA. **ClamAV** posee un actualizador de base de datos que permite las
actualizaciones programadas y firmas digitales a través del programa
**freshclam**. Dicha base de datos se actualiza diariamente con los nuevos
virus que se van encontrando. Además, el *antivirus* es capaz de
escanear de forma nativa diversos formatos de fichero como por ejemplo
Zip, BinHex, PDF, etc.

.. [#] Clam Antivirus: http://www.clamav.net/

En :menuselection:`Antivirus` se puede comprobar
si está instalado y actualizado el *antivirus* en el sistema.

.. image:: images/mailfilter/11-antivirus.png
   :scale: 80
   :align: center
   :alt: Mensaje del antivirus

Se puede actualizar desde :menuselection:`Gestión de Software`, como
veremos en :ref:`software-ref`.

Si el *antivirus* está instalado y actualizado, eBox lo tendrá en
cuenta dependiendo de la configuración del filtro SMTP, el *proxy
POP*, el *proxy HTTP* o incluso podría funcionar para la compartición
de ficheros.

Antispam
--------

El filtro anti*spam* asigna a cada correo un puntuación de *spam*, si
el correo alcanza la puntuación umbral de *spam* es considerado correo
basura, si no es considerado correo legitimo. A este ultimo tipo de
correo se le suele denominar *ham*.

El detector de spam usa las siguientes técnicas para asignar la puntuación:

 - Listas negras publicadas vía DNS (*DNSBL*).
 - Listas negras de URI que siguen los sitios *Web* de *Spam*.
 - Filtros basados en el *checksum* de los mensajes.
 - Entorno de política de emisor (*Sender Policy Framework* o SPF) :RFC:`4408`.
 - DomainKeys Identified Mail (DKIM)
 - Filtro bayesiano
 - Reglas estáticas
 - Otros. [#]_

Entre estas técnicas el *filtro bayesiano* debe ser explicado con más
detenimiento. Este tipo de filtro hace un análisis estadístico del
texto del mensaje obteniendo una puntuación que refleja la
probabilidad de que el mensaje sea *spam*. Sin embargo, el análisis no
se hace contra un conjunto estático de reglas sino contra un conjunto
dinámico, que es creado suministrando mensajes *ham* y *spam* al
filtro de manera que pueda aprender cuales son las características
estadísticas de cada tipo.

La ventaja de esta técnica es que el filtro se puede adaptar al
siempre cambiante flujo de *spam*, las desventajas es que el filtro
necesita ser entrenado y que su precisión reflejará la calidad del
entrenamiento recibido.

eBox usa **Spamassassin** [#]_ como detector de *spam*.

.. [#] Existe una lista muy larga de técnicas *antispam* que se puede
       consultar en http://en.wikipedia.org/wiki/Anti-spam_techniques_(e-mail)

.. [#] *The Powerful #1 Open-Source Spam Filter*
       http://spamassassin.apache.org .


La configuración general del filtro se realiza desde
:menuselection:`Filtro de correo --> Antispam`:

.. image:: images/mailfilter/12-antispam.png
   :scale: 80

Umbral de *Spam*:
  Puntuación a partir de la cual un correo se considera como *Spam*.
Etiqueta de asunto *Spam*:
  Etiqueta para añadir al asunto del correo en caso de que sea *Spam*.
Usar clasificador bayesiano:
  Si está marcado se empleará el filtro bayesiano, si no será ignorado.
Auto-lista blanca:
  Tiene en cuenta el historial del remitente a la hora de puntuar el
  mensaje. Esto es, si el remitente ha enviado mucho correo como *ham*
  es altamente probable que el próximo correo que envíe sea *ham* y no
  *spam*.
Auto-aprendizaje:
  Si está marcado, el filtro aprenderá de los mensajes recibidos, cuya
  puntuación traspase los umbrales de auto-aprendizaje.
Umbral de auto-aprendizaje de *spam*:
  Puntuación a partir de la cual el filtro aprenderá automáticamente un correo
  como *spam*. No es conveniente poner un valor bajo, ya que puede
  provocar posteriormente falsos positivos. Su valor debe ser mayor
  que **Umbral de** *spam*.
Umbral de auto-aprendizaje de *ham*:
  Puntuación a partir de la cual el filtro aprenderá automáticamente un correo
  como *ham*. No es conveniente poner un valor alto, ya que puede provocar
  falsos negativos. Su valor debería ser menor que 0.

Desde :guilabel:`Política de emisor` podemos marcar los remitentes
para que siempre se acepten sus correos (*whitelist*), para que
siempre se marquen como spam (*blacklist*) o que siempre los procese
el filtro antispam (*procesar*).

Desde :guilabel:`Entrenar filtro de spam bayesiano` podemos entrenar
al filtro bayesiano enviándole un buzón de correo en formato *Mbox*
[#]_ que únicamente contenga *spam* o *ham*. Existen en *Internet*
muchos ficheros de ejemplo para entrenar al filtro bayesiano, pero
suele ser más exacto entrenarlo con correo recibido en los sitios a
filtrar. Conforme más entrenado esté el filtro, mejor será el
resultado de la decisión de tomar un correo como basura o no.

.. [#] *Mbox* y *maildir* son formatos de almacenamiento de
   correos electrónicos y es dependiente del cliente de correo
   electrónico. En el primero todos los correos se almacenan en un único
   fichero y con el segundo formato, se almacenan en ficheros separados
   diferentes dentro de un directorio.


Listas de control basadas en ficheros
-------------------------------------

Es posible filtrar los ficheros adjuntos que se envían en los correos
a través de :menuselection:`Filtro de correo --> ACL por fichero`
(*File Access Control Lists*).

Allí podemos permitir o bloquear correos según las extensiones de los
ficheros adjuntos o de sus tipos MIME.

.. image:: images/mailfilter/06-filter-files.png
   :scale: 80

.. _smtp-filter-ref:

Filtrado de Correo SMTP
-----------------------

Desde :menuselection:`Filtro de correo --> Filtro de correo SMTP` se puede
configurar el comportamiento de los filtros anteriores cuando eBox
reciba correo por SMTP. Desde :menuselection:`General` podemos
configurar el comportamiento general para todo el correo entrante:

.. image:: images/mailfilter/07-filter-smtp.png
   :scale: 80
   :alt: Parámetros generales para el filtro SMTP

Habilitado:
  Marcar para activar el filtro SMTP.
Antivirus habilitado:
  Marcar para que el filtro busque virus.
Antispam habilitado:
  Marcar para que el filtro busque *spam*.
Puerto de servicio:
  Puerto que ocupará el filtro SMTP.
Notificar los mensajes problemáticos que no son *spam*:
  Podemos enviar notificaciones a una cuenta de correo cuando se
  reciben correos problemáticos que no son *spam*, por ejemplo con
  virus.

Desde :menuselection:`Políticas de filtrado` se puede configurar qué debe
hacer el filtro con cada tipo de correo.

.. image:: images/mailfilter/08-filter-smtp-policies.png
   :scale: 80
   :alt: Políticas del filtrado SMTP

Por cada tipo de correo problemático, se pueden realizar las siguientes
acciones:

Aprobar:
  No hacer nada, dejar pasar el correo a su destinatario.
Rechazar:
  Descartar el mensaje antes de que llegue al destinatario, avisando al
  remitente de que el mensaje ha sido descartado.
Rebotar:
  Igual que *Rechazar*, pero adjuntando una copia del mensaje en la
  notificación.
Descartar:
  Descarta el mensaje antes de que llegue al destinatario sin avisar al
  remitente.

Desde :menuselection:`Filtro de correo --> Filtro de correo SMTP -->
Dominios virtuales` se puede configurar el comportamiento del filtro
para los dominios virtuales de correo. Estas configuraciones
sobreescriben las configuraciones generales definidas previamente.

Para personalizar la configuración de un dominio virtual de correo, pulsamos
sobre :guilabel:`Añadir nuevo`.

.. image:: images/mailfilter/09-filter-domains.png
   :scale: 80
   :alt: Parámetros de filtrado por dominio virtual de correo

Los parámetros que se pueden sobreescribir son los siguientes:

Dominio:
  Dominio virtual que queremos personalizar. Tendremos disponibles aquellos que
  se hayan configurado en :menuselection:`Correo --> Dominio Virtual`.
Usar filtrado de virus / *spam*:
  Si están activados se filtrarán los correos recibidos en ese dominio en busca
  de virus o *spam* respectivamente.
Umbral de *spam*:
  Se puede usar la puntuación por defecto de corte para los correos *Spam*, o
  un valor personalizado.
Aprender de las carpetas IMAP de Spam de las cuentas:
  Si esta activado, cuando mensajes de correo se coloquen en la carpeta de Spam
  serán aprendidos por el filtro como spam. De manera similar si movemos un
  mensaje desde la carpeta de spam a una carpeta normal, sera aprendido como
  ham. 
Cuenta de aprendizaje de *ham* / *spam*:
  Si están activados se crearán las cuentas `ham@dominio` y `spam@dominio`
  respectivamente. Los usuarios pueden enviar correos a estas cuentas para
  entrenar al filtro. Todo el correo enviado a `ham@dominio` será aprendido como
  correo no *spam*, mientras que el correo enviado a `spam@dominio` será
  aprendido como *spam*.

Una vez añadido el dominio, se pueden añadir direcciones a su lista
blanca, lista negra o que sea obligatorio procesar desde
:menuselection:`Política antispam para el emisor`.

Listas de control de conexiones externas
========================================

Desde :menuselection:`Filtro de correo --> Filtro de correo SMTP --> Conexiones
externas` se pueden configurar las conexiones desde MTAs externos
mediante su dirección IP o nombre de dominio hacia el filtro de correo
que se ha configurado usando eBox. De la misma manera, se puede permitir a
esos MTAs externos filtrar correo de aquellos dominios virtuales
externos a eBox que se permitan a través de su configuración en esta
sección. De esta manera, eBox puede distribuir su carga en dos
máquinas, una actuando como servidor de correo y otra como servidor
para filtrar correo.

.. image:: images/mailfilter/13-external.png
   :scale: 80
   :align: center

.. _pop3-proxy-ref:

Proxy transparente para buzones de correo POP3
==============================================

Si eBox está configurado como un **proxy transparente**, puede filtrar el correo
POP. La máquina eBox se colocará entre el verdadero servidor POP y el
usuario filtrando el contenido descargado desde los servidores de
correo (MTA). Para ello, eBox usa **p3scan** [#]_.

.. [#] Transparent POP proxy http://p3scan.sourceforge.net/

Desde :menuselection:`Filtro de correo --> Proxy transparente POP` se puede
configurar el comportamiento del filtrado:

.. image:: images/mailfilter/10-filter-pop.png

Habilitado:
  Si está marcada, se filtrará el correo POP.
Filtrar virus:
  Si está marcada, se filtrará el correo POP en busca de virus.
Filtrar spam:
  Si está marcada, se filtrará el correo POP en busca de *spam*.
Asunto *spam* del ISP:
  Si el servidor de correo marca el *spam* con una cabecera,
  poniéndola aquí avisaremos al filtro para que tome los correos con
  esa cabecera como *spam*.

Ejemplo práctico
----------------

Activar el filtro de correo y el *antivirus*. Enviar un correo con virus.
Comprobar que el filtro surte efecto.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activar el módulo :guilabel:`filtro de correo`, para ello marcar su
   casilla en la columna :guilabel:`Estado`. Habilitar primero los
   módulos **red** y **cortafuegos** si no se encuentran habilitados
   con anterioridad.

   Efecto:
     eBox solicita permiso para sobreescribir algunos ficheros.

#. **Acción:**
   Leer los cambios de cada uno de los ficheros que van a ser modificados y
   otorgar permiso a eBox para sobreescribirlos.

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Acceder al menú :menuselection:`Filtro de Correo --> Filtro de
   correo SMTP`, marcar las casillas :guilabel:`Habilitado` y
   :guilabel:`Antivirus habilitado` y pulsar el botón
   :guilabel:`Cambiar`.

   Efecto:
     eBox nos avisa de que hemos modificado satisfactoriamente las opciones
     mediante el mensaje **Hecho**.

#. **Acción:**
   Acceder a :menuselection:`Correo --> General --> Opciones de
   Filtrado de Correo` y seleccionar :guilabel:`Filtro de correo
   interno de eBox`.

   Efecto:
     eBox usará su propio sistema de filtrado.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     El filtro de correo ha sido activado con la opción de antivirus.

#. **Acción:**
   Descargar el fichero http://www.eicar.org/download/eicar_com.zip, que
   contiene un virus de prueba y enviarlo desde nuestro cliente de correo a
   una de las cuentas de correo de eBox.

   Efecto:
     El correo nunca llegará a su destino porque el antivirus lo habrá
     descartado.

#. **Acción:**
   Acceder a la consola de la máquina eBox y examinar las últimas líneas del
   fichero `/var/log/mail.log`, por ejemplo mediante el uso del comando
   **tail**.

   Efecto:
     Observaremos que ha quedado registrado el bloqueo del mensaje
     infectado, especificándonos el nombre del virus::

         Blocked INFECTED (Eicar-Test-Signature)

.. include:: mailfilter-exercises.rst
