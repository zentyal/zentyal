Copias de seguridad
*******************

.. sectionauthor:: José Antonio Calvo <jacalvo@ebox-platform.com>
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>
                   Jorge Salamero <jsalamero@ebox-platform.com>

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

Otra de las decisiones importantes es si realizaremos las copias de seguridad sobre
la misma máquina o a otra remota. El uso de una máquina remota ofrece un
nivel de seguridad mayor debido a la separación física. Un fallo de *hardware*, un
fallo de *software*, un error humano o una intrusión en el servidor principal no
deberían de afectar la integridad de las copias de seguridad. Para minimizar este
riesgo el servidor de copias debería ser exclusivamente dedicado para tal fin y no
ofrecer otros servicios adicionales más allá de los requeridos para realizar las copias.
Tener dos servidores no dedicados realizando copias uno del otro es definitivamente
una mala idea, ya que un compromiso en uno lleva a un compromiso del otro.

Por último, con los argumentos anteriores se justifica un diseño en el
que el servidor de copias recoge los datos del servidor del que
queremos hacer copias de seguridad, y no al revés. El acceso
solamente es posible en este sentido, protegiendo las copias. El
objetivo es otra vez, que ante un compromiso en dicho servidor, no se
pueda obtener acceso a las copias.

Configuración de las copias de seguridad con eBox
-------------------------------------------------

Aunque se puede desplegar un sistema de copias de seguridad muy
complejo sobre cualquier máquina con eBox Platform, se ha comenzado
añadiendo soporte preliminar que permite configurar a través del
interfaz un sencillo sistema de copias de seguridad incrementales a un
disco duro local.

La herramienta utilizada para realizar estas copias es *rdiff-backup*
[#]_. Esta herramienta realiza las copias incrementales de manera
diferente, pues en lugar de tener una copia inicial más las
diferencias, mantiene una copia completa de la última versión y copias
incrementales hacia atrás. Gracias a esto, se tiene la ventaja de
poder acceder y restaurar la última versión de la copia se puede hacer
directamente. Utiliza el protocolo de *rsync* [#]_ que analiza el
origen y el destino copiando únicamente las diferencias con el
consiguiente ahorro de ancho de banda y además puede realizar la
transferencia usando *SSH*, simplificando su despliegue en la red.

.. [#] *rdiff-backup* <http://rdiff-backup.nongnu.org/>.
.. [#] *rsync* <http://rsync.samba.org/>.

Aunque se podrían realizar copias sobre el mismo disco duro en que está instalado el
sistema, no es nada recomendable hacerlo pues un fallo de disco afectaría a la
copia de seguridad, es por tanto el primer paso instalar un nuevo disco duro
en la máquina. Los discos duros son identificados normalmente como `/dev/sdx`
asignando una diferente letra a *x* para cada disco: a, b, c, etc.

El siguiente paso es crear en el disco una partición y sobre ella el sistema
de ficheros. El fichero `/proc/partitions` muestra los detalles de los discos
duros conectados y sus particiones. El siguiente ejemplo muestra una máquina
en la que el sistema está montado en el primer disco (`/dev/sda`) usando
LVM [#]_ y se ha conectado un segundo disco (`/dev/sdb`) todavía sin particionar::

    # cat /proc/partitions
    major minor  #blocks  name

       8        0  8388608 sda  <- primer disco
       8        1   248976 sda1 <- primera partición del primer disco
       8        2  8136922 sda2 <- segunda partición del primer disco
       8       16  1048576 sdb  <- segundo disco todavía sin particionar
     254        0  4194394 dm-0 <- primer volumen LVM
     254        1   524288 dm-1 <- segundo volumen LVM
     254        2  2097152 dm-2 <- tercer volumen LVM

.. [#] :ref:`LVM-section`

Para crear una partición usaremos la herramienta **cfdisk** seguida del nombre
del disco, siguiendo el ejemplo anterior `/dev/sdb`. Este paso es crítico.
Debemos ser especialmente cuidadosos en no modificar las particiones del
sistema, pues podríamos dejarlo completamente inoperativo::

    # cfdisk /dev/sdb

Usando el menú al pie de la pantalla, crearemos la partición:

.. figure:: images/backup/ebox_backup_01.png
   :scale: 50
   :alt: Seleccionar *[New]*
   :align: center

   Seleccionar *[New]*

.. figure:: images/backup/ebox_backup_02.png
   :scale: 50
   :alt: Seleccionar tipo de partición *[Primary]*
   :align: center

   Seleccionar tipo de partición *[Primary]*

.. figure:: images/backup/ebox_backup_03.png
   :scale: 50
   :alt: Seleccionar el tamaño por omisión *Size (in MB)* (todo el disco)
   :align: center

   Seleccionar el tamaño por omisión *Size (in MB)* (todo el disco)

.. figure:: images/backup/ebox_backup_04.png
   :scale: 50
   :alt: Guardar los cambios a la tabla de particiones con *[Write]*
   :align: center

   Guardar los cambios a la tabla de particiones con *[Write]*

.. figure:: images/backup/ebox_backup_05.png
   :scale: 50
   :alt: Confirmar los cambios con *yes*
   :align: center

   Confirmar los cambios con *yes*

.. figure:: images/backup/ebox_backup_06.png
   :scale: 50
   :alt: Salir con *[Quit]*
   :align: center

   Salir con *[Quit]*

Ahora podemos ver que la partición recién creada aparece en este ejemplo
como `/dev/sdb1`::

    # cat /proc/partitions
    major minor  #blocks  name

       8        0  8388608 sda  <- primer disco
       8        1   248976 sda1 <- primera partición del primer disco
       8        2  8136922 sda2 <- segunda partición del primer disco
       8       16  1048576 sdb  <- segundo disco
       8       17  1044193 sdb1 <- primera partición del segundo disco (recién creada)
     254        0  4194394 dm-0 <- primer volumen LVM
     254        1   524288 dm-1 <- segundo volumen LVM
     254        2  2097152 dm-2 <- tercer volumen LVM

Es el momento de crear el sistema de ficheros en la nueva partición. Otra vez
deberemos ser especialmente cuidadosos para no crearlo sobre otra partición,
pues destruiríamos los datos existentes en ella. En este ejemplo usaremos
*ext3* con la opción *dir_index* para mejor rendimiento::

    # mkfs.ext3 -O dir_index /dev/sdb1
    Filesystem label=
    OS type: Linux
    Block size=4096 (log=2)
    Fragment size=4096 (log=2)
    65280 inodes, 261048 blocks
    13052 blocks (5.00%) reserved for the super user
    First data block=0
    Maximum filesystem blocks=268435456
    8 block groups
    32768 blocks per group, 32768 fragments per group
    8160 inodes per group
    Superblock backups stored on blocks:
            32768, 98304, 163840, 229376

    Writing inode tables: done
    Creating journal (4096 blocks): done
    Writing superblocks and filesystem accounting information: done

    This filesystem will be automatically checked every 31 mounts or
    180 days, whichever comes first.  Use tune2fs -c or -i to override.

Ya podemos crear el punto de montaje::

    # mkdir /mnt/backup

Añadir la correspondiente línea al fichero `/etc/fstab` para que se monte
automáticamente al arranque::

    /dev/sdb1       /mnt/backup      ext3    noatime        0       1

Y finalmente y dejando ya listo el disco, montarlo::

    # mount /mnt/backup

Una vez tenemos el disco donde irán las copias, podemos habilitar
el módulo de copias de seguridad desde la interfaz en
:menuselection:`Estado del módulo` y tras :guilabel:`Guardar Cambios`
iremos a :menuselection:`Copia de Seguridad`. Aquí son tres los parámetros
que actualmente podemos configurar.

.. figure:: images/backup/ebox_ebackup.png
   :scale: 70
   :alt: Configuración del modulo **ebox-ebackup**
   :align: center

   Configuración del modulo **ebox-ebackup**


:guilabel:`Destino de la copia de seguridad`:
  Es el directorio dónde hemos montado el disco anteriormente y dónde
  se almacenarán las copias de seguridad. Por defecto es `/mnt/backup/`.

:guilabel:`Días a guardar`:
  Es el número de días a partir de los que rotamos las copias de seguridad.
  Las copias anteriores a este número de días serán borradas cuando la
  siguiente copia diaria se ejecute con éxito.

Tras :guilabel:`Guardar Cambios` podremos comprobar una vez que se haya
realizado la primera ejecución que la copia se encuentra en correcto
estado mediante el siguiente comando::

    # rdiff-backup -l /mnt/backup/
    Found 0 increments:
    Current mirror: Wed May 20 21:56:32 2009

Hay que mencionar que la versión actual del módulo todavía no permite
configurar los directorios incluidos en la copia de seguridad y
realiza una copia completa del sistema excluyendo los directorios
`/dev`, `/proc` y `/sys`, los cuales son auto-generados por el sistema
durante el arranque. Un registro del proceso de copia con *rdiff-backup*
se guarda en `/mnt/backup/ebox-backup.log` con fines informativos.

¿ Cómo recuperarse de un desastre ?
-----------------------------------

Tan importante es realizar copias de seguridad como conocer el procedimiento y
tener la destreza y experiencia para llevar a cabo una recuperación en un
momento crítico. Debemos ser capaces de reestablecer el servicio lo antes
posible cuando ocurre un desastre que deja el sistema no operativo.

Restaurar un fichero o un directorio es tan sencillo como ejecutar `rdiff-backup`
con el parámetro `-r` indicando `now` para la última copia o el número de días de
antigüedad de la copia de seguridad, seguido del origen de la copia y el destino
donde se restaurarán los ficheros::

    # rdiff-backup -r now /mnt/backup/etc/ebox /etc/ebox
    # rdiff-backup -r 10D /mnt/backup/home/samba/users/john /home/samba/users/john

En caso de desastre total, debemos arrancar el sistema a partir de un CD-ROM
como por ejemplo el instalador de eBox Platform (o cualquier instalador de
Ubuntu) en modo *rescue mode* usando la opción *Rescue a broken system*.

.. figure:: images/backup/ebox_restore_01.png
   :scale: 70
   :alt: Arrancar con *Rescue a broken system*
   :align: center

   Arrancar con *Rescue a broken system*

Inicialmente, seguiremos los mismos pasos que cuando se instala el
sistema.  Estas preguntas solamente configuran el sistema temporal sin
modificar nada del sistema instalado en el disco duro. Continuaremos
hasta que aparezca el menú de rescate.

En este menú seleccionaremos la partición dónde reside `/boot` en caso tener
el esquema de particiones idéntico al recomendado por los desarrolladores
(`/boot` + LVM). Seleccionaremos la partición dónde esté montado `/` en otro
caso. En este último caso ya tendremos el sistema montado bajo `/target`
restando de montar el resto de particiones.

.. figure:: images/backup/ebox_restore_02.png
   :scale: 50
   :alt: Seleccionar `/dev/sda1`
   :align: center

   Seleccionar `/dev/sda1`

.. figure:: images/backup/ebox_restore_03.png
   :scale: 50
   :alt: Seleccionar *Execute a shell in the installer environment*
   :align: center

   Seleccionar *Execute a shell in the installer environment*

.. figure:: images/backup/ebox_restore_04.png
   :scale: 50
   :alt: Se muestra un mensaje informativo
   :align: center

   Se muestra un mensaje informativo

.. figure:: images/backup/ebox_restore_05.png
   :scale: 50
   :alt: Se ofrece una *shell* restringida
   :align: center

   Se ofrece una *shell* restringida

Lo primero de todo es crear un punto de montaje para el disco duro de la copia
de seguridad y montarlo. La partición en este ejemplo que venimos siguiendo a lo
largo del capítulo es `/dev/sdb1`, con sistema de ficheros *ext3*::

    # mkdir /mnt/backup
    # mount -t ext3 /dev/sdb1 /mnt/backup

Ahora debemos crear otro punto de montaje para el directorio raíz del sistema de
ficheros y montarlo. El fichero
de dispositivo usado dependerá de qué esquema de particiones hayamos
elegido al instalar el sistema. En los ejemplos a continuación se presupone que
hemos usado etiquetas en las particiones. En otros casos deberemos fijarnos en cuál
es el fichero usado por el sistema, por ejemplo, si tenemos un solo disco SCSI y
una sola partición de ficheros, lo más probable es que el fichero del dispositivo
sea *dev/sda1*.  Una vez montado, borraremos
su contenido para restaurarlo todo por completo::

    # mkdir /mnt/ebox
    # mount -t ext3 /dev/ebox/root /mnt/ebox
    # rm -fr /mnt/ebox/*

En caso de tener otras particiones que fuera necesario restaurar
haríamos lo mismo, `/var` es un ejemplo típico, también deberíamos
hacer lo mismo con el resto de particiones del sistema en caso de
haber sido afectadas (`/home`, `/var/vmail`, etc.)::

    # mkdir /mnt/ebox/var
    # mount -t xfs /dev/ebox/var /mnt/ebox/var
    # rm -fr /mnt/ebox/var/*

Y ya podemos restaurar la copia de seguridad::

    # cd /mnt/backup/
    # cp -ra * /mnt/ebox/

Es ahora cuando hay que arreglar a mano algunas cosas para que el sistema arranque.
En el caso de que no hayan sido recreados por el proceso de recuperación,
tendremos que crear los directorios excluidos de la copia de seguridad. También
deberemos limpiar los directorios temporales y borrar un fichero generado por *rdiff-backup*::

    # mkdir -p /mnt/ebox/dev
    # mkdir -p /mnt/ebox/sys
    # mkdir -p /mnt/ebox/proc
    # rm -fr /mnt/ebox/var/run/*
    # rm -fr /mnt/ebox/var/lock/*
    # rm -fr /mnt/ebox/rdiff-backup-data


Sólo queda restaurar la partición `/boot` montada en `/target`. Si usamos la 
misma partición para  `/boot`  y  `/` deberemos saltarnos este paso o perderemos
nuestros archivos en  `/`. Los comandos para restaurar la partición `/boot` son::

    # rm -fr /target/*
    # mv /mnt/ebox/boot/* /target/


En el caso que hayamos montado más particiones sobre `/mnt/ebox` deberemos
desmontarlas::

    # umount /mnt/ebox/var

Creamos los directorios `/var/run` y `/var/lock`, necesarios para poder arrancar
el sistema. Desmontamos el sistema y salimos del programa de instalación::

    # mkdir -p /mnt/ebox/var/run
    # mkdir -p /mnt/ebox/var/lock
    # umount /mnt/ebox
    # exit

La restauración ha concluido y podemos reiniciar al sistema de nuevo.

.. figure:: images/backup/ebox_restore_06.png
   :scale: 50
   :alt: Seleccionar *Reboot the system*
   :align: center

   Seleccionar *Reboot the system*


Copias de seguridad de la configuración
---------------------------------------

eBox Platform dispone adicionalmente de otro método para realizar copias
de seguridad de la configuración y restaurarlas desde la propia interfaz.
Este método guarda la configuración de todos los módulos que hayan sido
habilitados por primera vez en algún momento, los usuarios del LDAP y
cualquier otro fichero adicional para el funcionamiento de cada módulo.

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

En la sección :guilabel:`Restaurar backup desde fichero` podemos enviar
un fichero de copia de seguridad que tengamos previamente descargado,
por ejemplo, perteneciente a una instalación anterior de eBox Platform
en otra máquina, y restaurarlo mediante :guilabel:`Restaurar`.
Al restaurar se nos pedirá confirmación, hay que tener cuidado porque la
configuración actual será reemplazada por completo. El proceso de
restauración es similar al de copia, después de mostrar el progreso se
nos notificará el éxito de la operación si no se ha producido ningún error.


Herramientas de linea de comandos para copias de seguridad de la configuración
------------------------------------------------------------------------------

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
