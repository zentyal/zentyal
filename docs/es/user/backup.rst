Copias de seguridad
*******************

.. sectionauthor:: José Antonio Calvo <jacalvo@ebox-platform.com>
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>
                   Jorge Salamero <jsalamero@ebox-platform.com>
                   Javier Uruen Val <juruen@ebox-platform.com>

Diseño de un sistema de copias de seguridad
-------------------------------------------

La pérdida de datos en un sistema es un accidente ocasional ante el que
debemos estar prevenidos. Fallos de *hardware*, fallos de *software* o un
error humano pueden provocar un daño irreparable en el sistema o la
pérdida de datos importantes.

Es por tanto imprescindible diseñar un correcto **procedimiento para realizar,
comprobar y restaurar copias de seguridad** o respaldo del sistema, tanto
de configuración como de datos.

Una de las primeras decisiones que deberemos tomar es si realizaremos
**copias completas**, es decir, una copia total de todos los datos, o
**copias incrementales**, esto es, a partir de una primera copia
completa copiar solamente las diferencias. Las copias incrementales
reducen el espacio consumido para realizar copias de seguridad aunque
requieren lógica adicional para la restauración de la copia de
seguridad.  La decisión más habitual es realizar copias incrementales
y de vez en cuando hacer una copia completa a otro medio, pero esto
dependerá de nuestras necesidades y recursos de almacenamiento
disponibles.

.. TODO: Graphic with differences between full backup and incremental backup

Otra de las decisiones importantes es si realizaremos las copias de
seguridad sobre la misma máquina o a otra remota. El uso de una
máquina remota ofrece un nivel de seguridad mayor debido a la
separación física. Un fallo de *hardware*, un fallo de *software*, un
error humano o una intrusión en el servidor principal no deberían de
afectar la integridad de las copias de seguridad. Para minimizar este
riesgo el servidor de copias debería ser exclusivamente dedicado para
tal fin y no ofrecer otros servicios adicionales más allá de los
requeridos para realizar las copias.  Tener dos servidores no
dedicados realizando copias uno del otro es definitivamente una mala
idea, ya que un compromiso en uno lleva a un compromiso del otro.

Configuración de las copias de seguridad con eBox
-------------------------------------------------

En primer lugar, debemos decidir si almacenamos nuestras copias de
seguridad local o remotamente. En caso de éste último, necesitaremos
especificar que protocolo se usa para conectarse al servidor remoto.

.. figure:: images/backup/ebox_ebackup_01.png
   :scale: 80
   :alt: Configuración
   :align: center

   Configuración


:guilabel:`Método`:
  Los distintos métodos que son soportados actualmente son *eBox
  Backup Storage (EU)*, *eBox Backup Storage (US Denver)*, *eBox
  Backup Storage (US West Coast)*, *FTP*, *SCP* y *Sistema de
  ficheros*. Debemos tener en cuenta que dependiendo del método que
  seleccione deberemos proporcionar más o menos información: dirección
  del servidor remoto, usuario o contraseña. Todos los métodos salvo
  *Sistema de ficheros* acceden servicios remotos. Ésto significa que
  proporcionaremos los credenciales adecuados para conectar con el
  servidor.  Puedes crear una cuenta en nuestra tienda [#]_ para los
  métodos *eBox Backup Storage*, emplea este servicio para disfrutar
  de una ubicación segura remota donde almacenar tus datos. Además no
  necesitarás incluir la dirección del servidor remoto ya que eBox lo
  tendrá configurado automáticamente. Por otro lado, si se selecciona
  *FTP* o *SCP* tendremos que introducir la dirección del servidor
  remoto.

.. [#] Tienda de eBox Technologies en https://store.ebox-technologies.com

.. warning::
    Si usamos *SCP*, tendremos que ejecutar `sudo ssh
    usuario@servidor` y aceptar la huella del servidor remoto para
    añadirlo a la lista de servidores SSH conocidos.  Si no se realiza
    esta operación, la copia de respaldo no podrá ser realizada ya que
    fallará la conexión con el servidor.

:guilabel:`Servidor o destino`:
   Para *FTP*, y *SCP* tenemos que proporcionar el nombre del servidor
  remoto o su dirección IP. En caso de usar *Sistema de ficheros*,
  introduciremos la ruta de un directorio local. Si se usa cualquiera
  de los métodos de *eBox Backup Storage*, entonces sólo se requiere
  introducir una ruta relativa.

:guilabel:`Usuario`:
  Nombre de usuario para autenticarse en la máquina remota.

:guilabel:`Contraseña`:
  Contraseña para autenticarse en la máquina remota.

:guilabel:`Cifrado`:
  Se puede cifrar los datos de la copia de seguridad usando una clave
  simétrica que se introduce en el formulario, o se puede seleccionar
  una clave GPG ya creada para dar cifrado asimétrico a tus datos.

:guilabel:`Frecuencia de copia de seguridad completa`:
  Este parámetro se usa para determinar la frecuencia con la que las copias de
  seguridad completas se llevan a cabo. Los valores son: *Diario*, *Semanal* y
  *Mensual*. Si seleccionas *Semanal* o *Mensual*, aparecerá un segundo control
  para poder seleccionar el día exacto de la semana o del mes en el que se 
  realizara la copia.

:guilabel:`Frecuencia de copia incremental`:
  Este valor selecciona la frecuencia de la copia incremental o la deshabilita.

  Si la copia incremental esta activa podemos seleccionar una frecuencia *Diaria*
  o *Semanal*. La frecuencia seleccionada debe ser mayor que la frecuencia de
  copia completa.

  En los días en que se realice una copia completa, se saltara cualquier copia
  incremental programada.

:guilabel:`Comienzo de copia de respaldo`:
  Este campo es usado para indicar cuando comienza el proceso de la toma de la
  copia de respaldo, tanto el completo como el incremental. Es una buena idea establecerlo a horas cuando no haya nadie
  en la oficina ya que puede consumir bastante ancho de banda de subida.

:guilabel:`Número de copias totales almacenadas`:
  Este valor se usa para limitar el número de copias totales que están
  almacenadas. Puedes elegir limitar por numero o por antigüedad.

  Si limitas por numero, solo el numero indicados de copias sera guardado; la
  ultima copia completa no se cuenta.
  En el caso que limites por antigüedad, sol ose guardaran las copias completas
  que sean mas recientes que el periodo indicado.

  Cuando una copia completa se borra, todas las copias incrementales realizadas
  a partir de ella también son borradas.


Configuración de los directorios y ficheros que son respaldados
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

La configuración por defecto efectuará una copia de todo el sistema de
ficheros excepto los ficheros o directorios explícitamente excluidos.   En el
caso que usemos el método *Sistema de ficheros*, el directorio objetivo y todo
su contenido es automáticamente excluido.

Puedes establecer exclusiones de rutas y exclusiones por expresión regular. Las
exclusiones por expresión regular excluirán cualquier ruta que coincida con
ella. Cualquier directorio excluido, excluirá también todo su contenido.

Para refinar aun mas el contenido de la copia de seguridad también puedes
definir  *inclusiones* , cuando un ruta coincide con una inclusión antes de
coincidir con alguna exclusión, sera incluida en el backup.

El orden en que se aplican las inclusiones y exclusiones se puede alterar
usando los iconos de flechas.

.. note
Puedes excluir archivos por su extensión usando una exclusión con expresión
regular.  Por ejemplo si quieres que los archivos *AVI no figuren en la copia de
respaldo, puedes seleccionar *Exclusión por expresión regular* y añadir `\.avi$`.

La lista por defecto de directorios excluidos es: `/mnt`, `/dev`,
`/media`, `/sys`, `/tmp`, `/var/cache` y `/proc`. Es una mala idea incluir alguno de estos
directorios ya que como resultado el proceso de copia de respaldo
podría fallar.

Una copia completa de un servidor eBox con todos sus módulos pero sin datos de
usuario ocupa unos 300 MB.

.. figure:: images/backup/ebox_ebackup_03.png
   :scale: 80
   :alt: Lista de inclusión y exclusión
   :align: center

   Lista de inclusión y exclusión

Comprobando el estado de las copias
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Podemos comprobar el estado de las copias de respaldo en la sección *Estado de
las copias remotas*. En esta tabla podemos ver el tipo de copia, completa o
incremental, y la fecha de cuando fue tomada.

.. note
  Si por cualquier razón borras manualmente los archivos del backup, puedes
  forzar a regenerar este listado con el comando::
  # /etc/init.d/ebox ebackup restart

.. figure:: images/backup/ebox_ebackup_02.png
   :scale: 80
   :alt: Estado de las copias
   :align: center

   Estado de las copias

Cómo iniciar un proceso de copia de respaldo manualmente
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

El proceso de copia de respaldo se inicia automáticamente a la hora configurada.
Sin embargo, si necesitamos comenzarlo manualmente podemos ejecutar::

    # /usr/share/ebox-ebackup/ebox-remote-ebackup --full

O para iniciar una copia incremental::

    # /usr/share/ebox-ebackup/ebox-remote-ebackup --incremental


Restaurar ficheros
~~~~~~~~~~~~~~~~~~

Hay dos formas de restaurar un fichero. Dependiendo del tamaño del fichero o del
directorio que deseemos restaurar.

Es posible restaurar ficheros directamente desde el panel de control
de eBox. En la sección :menuselection:`Copia de seguridad -->
Restaurar ficheros` tenemos acceso a la lista de todos los ficheros y
directorios que contiene la copia remota, así como las fecha de las distintas
versiones que podemos restaurar.

Si la ruta a restaurar es un directorio todos sus contenidos se restauraran,
incluyendo subdirectorios.

El archivo se restaurar con sus contenidos en la fecha seleccionada, si el
archivo no esta presente en la copia de respaldo en esa fecha se restaurara la
primera versión que se encuentre en las copias anteriores a la indicada; si no
existen versiones anteriores se notificara con un mensaje de error.

.. warning
Los archivos mostrados en la interfaz son aquellos que están presentes en la
ultima copia de seguridad. Los archivos que están almacenados en copias
anteriores pero no en la ultima no se muestran, pero pueden ser restaurados a
través de la linea de comandos.


 Podemos usar este método con
ficheros pequeños. Con ficheros grandes, el proceso es costoso en
tiempo y no se podrá usar el interfaz *Web* de eBox mientras la
operación está en curso. Debemos ser especialmente cautos con el tipo
de fichero que restauramos. Normalmente, será seguro restaurar
ficheros de datos que no estén siendo abiertos por aplicaciones en ese
momento. Estos archivos de datos están localizados bajo el directorio
`/home/samba`. Sin embargo, restaurar ficheros del sistema de
directorios como `/lib`, `/var` o `/usr` mientras el sistema está en
funcionamiento puede ser muy peligroso. **No** hagas ésto a no ser que
sepas muy bien lo que estás haciendo.

.. figure:: images/backup/ebox_ebackup_04.png
   :scale: 80
   :alt: Restaurar un fichero
   :align: center

   Restaurar un fichero

Los ficheros grandes y los directorios y ficheros de sistema deben ser
restaurados manualmente. Dependiendo del fichero, podemos hacerlo mientras el
sistema está en funcionamiento. Sin embargo, para directorios de sistema
usaremos un CD de rescate como explicamos más tarde.

En cualquier caso, debemos familiarizarnos con la herramienta que usa este
módulo: **duplicity**. El proceso de restauración de un fichero o directorio es
muy simple. Se ejecuta el siguiente comando::

  duplicity restore --file-to-restore -t 3D <fichero o directorio a restaurar> <URL remota y argumentos> <destinos>

.. [#] *duplicity*: Encrypted bandwidth-efficient backup using the
       rsync algorithm <http://duplicity.nongnu.org/>.

La opción *-t* se usa para seleccionar la fecha que queremos restaurar. En este
caso, *3D* significa hace tres días. Usando *now* podemos restaurar la copia más
actual.

Podemos obtener *<URL remota y argumentos* leyendo la nota que se encuentra
encima de la sección :guilabel:`Restaurar ficheros` en eBox.

.. figure:: images/backup/ebox_ebackup_05.png
   :scale: 80
   :alt: <URL remota y argumentos>
   :align: center

   URL remota y argumentos

Por ejemplo, si queremos restaurar el fichero
`/home/samba/users/john/balance.odc` ejecutaríamos el siguiente comando::

    # duplicity restore --file-to-restore home/samba/users/john/balance.odc \
      scp://backupuser@192.168.122.1 --ssh-askpass --no-encryption /tmp/balance.odc

El comando mostrado arriba restauraría el fichero en `/tmp/balance.odc`. Si
necesitamos sobreescribir un fichero o un directorio durante una operación de
restauración necesitamos añadir la opción *--force*, de lo contrario *duplicity*
rechazará sobreescribir los archivos.

Como recuperarse de un desastre
-------------------------------

Tan importante es realizar copias de seguridad como conocer el procedimiento y
tener la destreza y experiencia para llevar a cabo una recuperación en un
momento crítico. Debemos ser capaces de restablecer el servicio lo antes
posible cuando ocurre un desastre que deja el sistema no operativo.

Para recuperarnos de un desastre total, arrancaremos el sistema usando un
CD-ROM de rescate que incluye el software de copia de respaldos *duplicity*.
El nombre de este CD-ROM es *grml*.

.. [#] *grml* <http://www.grml.org/>.

Descargaremos la imagen de *grml* y arrancaremos la máquina con ella.
Usaremos el parámetro *nofb* en caso de problemas con el tamaño de la pantalla.

.. figure:: images/backup/ebox_restore_01.png
   :scale: 80
   :alt: Arranque grml
   :align: center

   Arranque grml

Una vez que el proceso de arranque ha finalizado podemos obtener un
intérprete de comandos pulsando la tecla :kbd:`enter`.

.. figure:: images/backup/ebox_restore_02.png
   :scale: 80
   :alt: Comenzar un intérprete de comandos
   :align: center

   Comenzar un intérprete de comandos

Si nuestra red no está configurada correctamente, podemos ejecutar
`netcardconfig` para configurarla.

El siguiente paso es montar el disco duro de nuestro sistema. En este caso, vamos a
suponer que nuestra partición raíz es `/dev/sda1`. Así que ejecutamos::

    # mount /dev/sda1 /mnt

El comando de arriba montará la partición en el directorio `/mnt`. En este ejemplo
haremos una restauración completa. Primero eliminaremos todos los directorios existentes
en la partición. Por supuesto, si no haces una restauración completa este paso no es necesario.

Para eliminar los ficheros existentes y pasar a la restauración ejecutamos::

    # rm -rf /mnt/*

Instalaremos *duplicity* en caso de no tenerlo disponible::

    # apt-get update
    # apt-get install duplicity

Antes de hacer una restauración completa necesitamos restaurar
`/etc/passwd` y `/etc/group`. En caso contrario, podemos tener problemas al
restaurar archivos con el propietario incorrecto. El problema se debe a
que *duplicity* almacena los nombres de usuario y grupo y no los valores
numéricos. Así pues, tendremos problemas si restauramos ficheros en un
sistema en el que el nombre de usuario o grupo tienen distinto UID o GID.
Para evitar este problema sobreescribimos `/etc/passwd` y `/etc/group` en
el sistema de rescate. Ejecutamos::

    # duplicity restore --file-to-restore etc/passwd \
    # scp://backupuser@192.168.122.1 /etc/passwd --ssh-askpass --no-encryption --force

    # duplicity restore --file-to-restore etc/group \
    # scp://backupuser@192.168.122.1 /etc/group --ssh-askpass --no-encryption --force

.. warning::
    Si usamos *SCP*, tendremos que ejecutar `sudo ssh
    usuario@servidor` para añadir el servidor remoto a la lista de
    servidores SSH conocidos. Si no se realiza esta operación, la
    copia de respaldo no podrá ser realizada ya que fallará la
    conexión con el servidor.

Ahora podemos proceder con la restauración completa ejecutando  *duplicity*
manualmente::

    # duplicity restore  scp://backupuser@192.168.122.1 /mnt/ --ssh-askpass --no-encryption --force

Por último debemos crear los directorios excluidos de la copia de
respaldo así como limpiar los directorios temporales::

    # mkdir -p /mnt/dev
    # mkdir -p /mnt/sys
    # mkdir -p /mnt/proc
    # rm -fr /mnt/var/run/*
    # rm -fr /mnt/var/lock/*


El proceso de restauración ha finalizado y podemos reiniciar el sistema
original.


Restaurando servicios
----------------------

Además de los archivos se almacenan datos para facilitar la restauración directa
de algunos servicios. Estos datos son:
 * copia de seguridad de la configuración de eBox.
 * copia de seguridad de la base de datos de registros de eBox

En la pestaña *Restauración de servicios* ambos pueden ser restauraros para una
fecha dada.

La copia de seguridad de la configuración de eBox guarda la configuración de
todos los módulos que hayan sido 
habilitados por primera vez en algún momento, los datos del LDAP y
cualquier otro fichero adicional para el funcionamiento de cada módulo.

Debes tener cuidado al restaurar la configuración de eBox ya que toda la
configuración y los datos de LDAP serán remplazados. Sin embargo, en el caso de
la configuración no almacenad en LDAP deberás pulsar en "Guardar cambios" para
que se ponga en vigor.

.. _conf-backup-ref:

Copias de seguridad de la configuración
---------------------------------------

eBox Platform dispone adicionalmente de otro método para realizar copias
de seguridad de la configuración y restaurarlas desde la propia interfaz.


También permite realizar copia de seguridad de los datos que almacena
cada módulo (directorios de usuarios, buzones de voz, etc.). Sin
embargo, desde la versión 1.2 se desaconseja esta opción en favor del
método comentado anteriormente a lo largo de este capítulo, ya que no
está preparado el sistema para manejar grandes cantidades de datos.

Para acceder a las opciones de estas copias de seguridad lo haremos,
como de costumbre, a través del menú principal :menuselection:`Sistema
--> Backup`.  No se permite realizar copias de seguridad si existen
cambios en la configuración sin guardar, como puede verse en el aviso
que aparece en la imagen.

.. image:: images/backup/ebox_backup.png
   :scale: 60
   :alt: Realizar una copia de seguridad
   :align: center

Una vez introducido un :guilabel:`nombre` para la copia de seguridad,
seleccionado el tipo deseado (configuración o completo) y
pulsando el botón :guilabel:`Backup`, aparecerá una pantalla donde se mostrará
el progreso de los distintos módulos hasta que finalice con el mensaje de
**Backup finalizado con éxito**.

Posteriormente, si volvemos a acceder a la pantalla anterior, veremos
que en la parte inferior de la página aparece una :guilabel:`Lista
de backups`. A través de esta lista podemos restaurar, descargar a nuestro
disco, o borrar cualquiera de las copias guardadas. Así mismo aparecen
como datos informativos el tipo de copia, la fecha de realización de la
misma y el tamaño que ocupa.

En la sección :guilabel:`Restaurar backup desde un archivo` podemos enviar
un fichero de copia de seguridad que tengamos previamente descargado,
por ejemplo, perteneciente a una instalación anterior de eBox Platform
en otra máquina, y restaurarlo mediante :guilabel:`Restaurar`.
Al restaurar se nos pedirá confirmación, hay que tener cuidado porque la
configuración actual será reemplazada por completo. El proceso de
restauración es similar al de copia, después de mostrar el progreso se
nos notificará el éxito de la operación si no se ha producido ningún error.


Herramientas de linea de comandos para copias de seguridad de la configuración
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Existen dos herramientas disponibles a través de la línea de comandos
que también nos permiten guardar y restaurar la configuración
. Residen en `/usr/share/ebox`, se denominan `ebox-make-backup` y
`ebox-restore-backup`.

**ebox-make-backup** nos permite realizar copias de seguridad de la
configuración, entre sus opciones están elegir qué tipo de copia de
seguridad queremos realizar. Entre estos está el *bug-report* que
ayuda a los desarrolladores a arreglar un fallo al enviarlo,
incluyendo información extra. Cabe destacar que en este modo,
las contraseñas de los usuarios son reemplazadas para mayor confidencialidad.
Este tipo de copia de seguridad no se puede realizar desde la interfaz web.

Podemos ver todas las opciones del programa con el parámetro `--help`.

`ebox-restore-backup` nos permite restaurar ficheros de copia de
seguridad de la configuración. Posee también una opción para extraer
la información del fichero. Otra opción a señalar es la posibilidad de
hacer restauraciones parciales, solamente de algunos módulos en
concreto. Es el caso típico cuando queremos restaurar una parte de una
copia de una versión antigua. También es útil cuando el proceso de
restauración ha fallado por algún motivo. Tendremos que tener especial
cuidado con las dependencias entre los módulos. Por ejemplo, si
restauramos una copia del módulo de cortafuegos que depende de una
configuración del módulo objetos y servicios debemos
restaurar también estos primero. Aún así, existe una opción para
ignorar las dependencias que puede ser útil usada con precaución.

Si queremos ver todas las opciones de este programa podemos usar
también el parámetro `--help`.

.. include:: backup-exercises.rst
