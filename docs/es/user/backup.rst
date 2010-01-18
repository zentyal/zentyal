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

Backup configuration with eBox
------------------------------

Primeramente, debemos decidir si almacenamos nuestras copias de seguridad local
o remótamente. En caso de éste último, necesitaremos especificar que protocolo
se usa para conectarse al servidor remoto.

.. figure:: images/backup/ebox_ebackup_01.png
   :scale: 80
   :alt: Configuración
   :align: center

   Select Configuración


:guilabel:`Método`:
Los distintos métodos que son soportados actualmente son *iBackup*, *RSYNC*,
*FTP*, *SCP* y *Sistema de ficheros*. Debemos tener en cuenta que dependiendo
del método que seleccione deberemos proporcionar más o menos infomación:
dirección del servidor remoto, usario o contraseña. Todos los métodos salvo
*Sistema de ficheros* acceden servicios remotos. Ésto significa que
proporcionaremos los credenciales adecuados para conectar con el servidor.
Puedes crear una cuenta *TODO* haciendo click sobre el enlace. Por otro lado, si
se selecciona *RSYNC*, *FTP* o *SCP* tendremos que introducir la dirección del
servidor remoto.

.. warning::
    Si usamos *SCP*, tendremos que ejecutar `sudo ssh usuario@servvidor`para
    añadir el servidor remoto a la lista de servidores SSH conocidos. Si no se
    realiza esta operación, la copia de respaldo no podrá ser realizada ya que
    fallará la conexión con el servidor.

:guilabel:`Servidor o destino`:
Para *RSYNC*, *FTP*, y *SCP* tenemos que proporcionar el nombre del servidor
remoto o su dirección IP. En caso de usar *Sistema de ficheros*, introduciremos
la ruta de un directorio local.

.. warning::
    Si usamos *Sistema de ficheros* deberemos crear manualmente el directorio.

:guilabel:`Usario`:
Nombre de usuario para autenticarse en la máquina remota.

:guilabel:`Contraseña`:
Contraseña para autenticarse en la máquina remota.

:guilabel:`Clave GPG`:
Podemos seleccionar una clave GPG para cifrar y descifrar nuestra copia de
respaldo.

:guilabel:`Frecuencia de copia de seguridad completa`:
Este parámetro se usa para determinar la frecuencia con la que las copias de
seguridad completas se llevan a cabo. Los valores son: *Diario*, *Semanal* y
*Mensual*.

:guilabel:`Número de copias totales almacenadas`:
Este valor se usa para limitar el número de copias totales que están
almacenadas. Es importante y debemos familiarizarnos con lo que significa.
Tiene relación directa con *Frecuencia de copia de seguridad completa*. Si
seleccionamos una frecuencia *Semanal* y el número de copias almacenadas a 2, la
copia de respalando más antigua será de dos semanas. De forma similar,
seleccionando *Mensual* y 4, la copia de respaldo más antigua será de 4 meses.
Deberemos seleccionar un valor acorde a el periodo que queramos almacenar de las
copias de respaldo y el espacio en disco que tengamos.

:guilabel:`Frecuencia de copia incremental`:
Este valor también está relacionado con *Frecuencia de copia de seguridad
completa*. Una configuración típica de copias de respaldo consiste en realizar
copias incrementales entre las copias completas. Estas copias deben hacerse con
más frecuencia que las completas. Esto significa que si tenemos copias completas
semanales, las copias incrementales se harán diarias. Por el contrario, no tiene
sentido hacer copias incrementales con las misma frecuencia que las completas.
Para entender ésto mejor veamos un ejemplo:

El valor de *Frecuencia de copia complea*  es semanal. El *Numero de copias
totales a almacenar* es 4. Con esta configuración tendremos cuatro copias de
seguridad completas de cuatro semanas, y entre cada copia completa tendremos
copias incrementales. Es decir, un mes entero de copias. Lo que significa que
podemos restaurar cualquier día arbitrario del mes.

:guilabel:`Comienzo de copia de respaldo`:
Este campo es usado para indicar cuando comieza el proceso de la toma de la
copia de respaldo. Es una buena idea establecerlo a horas cuando no haya nadie
en la oficina ya que puede consumir bastante ancho de banda.

Configuración de los directorios y ficheros que son respaldados
---------------------------------------------------------------
La configuración por defecto efectuará una copia de todo el sistema de ficheros.
Esto significa que ante un eventual desastre seremos capaces de restaurar la
máquina completamente. Es un buena idea no cambiar esta configuración al menos
que tengas problemas de espacio. Una copia completa de una máuina eBox con todos
sus módulos ocupa alrededor de 300 MB.

.. figure:: images/backup/ebox_ebackup_03.png
   :scale: 80
   :alt: Lista de inclusión y exclusióm
   :align: center

   Lista de inclusión y exclusión

La lista por defecto de directorios excluídos es: */mnt*, */dev*, */media*, */sys*,
y */proc*. Es una mala idea incluir alguno de estos directorios ya que como
resultado el proceso de copia de respaldo podría fallar.

La lista por defecto de directorios incluídos es: */*.

Podemos ignorar extensiones de fichero utilizando caracteres de shell.

Comprobando el estado de las copias
-----------------------------------
Podemos comprobar el estado de las copias de respaldo en la sección *Estado de
las copias remotas*. En esta tabla podemos ver el tipo de copia, completa o
incremental, y la fecha de cuando fue tomada.

.. figure:: images/backup/ebox_ebackup_02.png
   :scale: 80
   :alt: Estado de las copias
   :align: center

   Estado de las copias

Restaurar archivos
------------------
Hay dos formas de restaurar un archivo. Dependiendo del tamño del fichero o del
directorio que deseemos restaurar.

Es posbile restaurar archivos directamente desde el panel de control de eBox. En
la sección *Restaurar archivos* tenemos acceso a la lista de todos los ficheros
y directorios que contiene la copia remota, así como las distintas fechas o
versiones de los mismos. Podemos usar este metodo con archivos pequeños.Con
archivos grandes, el proceso es costoso en tiempo y no se podrá usar el interfaz
Web de eBox mientras la operación está en curso. Debemos ser especialmente
cautos con el tipo de archivo que restauramos. Normalmente, será seguro
restaurar archivos de datos que no estén siendo abiertos por aplicaciones en ese
momento. Estos archivos de datos están localizados bajo el directorio
*/home/samba*. Sin embargo, restaurar ficheros del sistema de directorios como
*/lib*, */var*, o */usr* mientras el sistema está en funcionamiento puede ser
muy peligroso. No hagas ésto a no ser que sepas muy bien lo que estás haciendo.

.. figure:: images/backup/ebox_ebackup_04.png
   :scale: 80
   :alt: Restaurar un fichero
   :align: center

   Restaurar un fichero

Los archivos grande y los directorios y ficheros de sistema deben ser
restaurados manualmente. Dependendiendo del archivo, podemos hacerlo mientras el
sistema está en funcionamiento. Sin embargo, para directorios de sistema
usaremos un CD de rescate como explicamos más tarde.

En cualquier caso, debemos familiarizarnos con la herramienta que usa este
módulo: *duplicity*. El proceso de restauración de un fichero o directorio es
muy simple. Se ejecuta el siguiente comando: `duplicity restore
--file-to-restore -t 3D <fichero o directorio a restaurar> <URL remota y argumentos> <destinos>`.

.. [#] *duplicity* <http://duplicity.nongnu.org/>.

La opción *-t* se usa para seleccionar la fecha que queremos restaurar. En este
caso, *3D* significa hace tres días. Usando *now* podemos restaurar la copia más
actual.

Podemos optener *<URL remota y argumentos* leyendo la nota que se encuentra
encima de la sección *Restaurar archivos* en eBox.

.. figure:: images/backup/ebox_ebackup_05.png
   :scale: 80
   :alt: <URL remota y argumentos>
   :align: center

   URL remota y argumentos

Por ejemplo, si queremos restaurar el archivo
*/home/samba/users/john/balance.odc* ejecutaríamos el siguiente comando::
    
    # duplicity restore --file-to-restore home/samba/users/john/balance.odc \
      scp://backupuser@192.168.122.1 --ssh-askpass --no-encryption /tmp/balance.odc

El comando mostrado arriba restauraría el fichero en */tmp/balance.odc*. Si
necesitamos sobreescribir un fichero o un directorio durante una operación de
restauración necesitamos añadir la opción *--force*, de lo contrario duplicity
rechazará sobreescribir los archivos.

Como recuperarse de un desastre
-------------------------------

Tan importante es realizar copias de seguridad como conocer el procedimiento y
tener la destreza y experiencia para llevar a cabo una recuperación en un
momento crítico. Debemos ser capaces de reestablecer el servicio lo antes
posible cuando ocurre un desastre que deja el sistema no operativo.

Para recuperarnos de un desastre total, arrancaremos el sistema usando un
CD-ROM de rescate que incluye el software de copia de respaldos duplicity.
El nombre de este CD-ROm es *grml*.

.. [#] *grml* <http://www.grml.org/>.

Descargaremos la imagen de *grml* y arrancaremos la máquina con ella.
Usaremos el parámetro *nofb* en caso de problemas con el tamaño de la pantalla.

.. figure:: images/backup/ebox_restore_01.png
   :scale: 80
   :alt: arrancque grml
   :align: center

   arranque grml


Una vez que el proceso de arranque ha finalizado podemos obtener un
intérprete de comandos pulsando la tecla *enter*.

.. figure:: images/backup/ebox_restore_02.png
   :scale: 80
   :alt: comenzar un intérprete de comandos
   :align: center

   comenzar un intérprete de comandos

Si nuestra red no está configurada correctamente, podemos ejecutar
`netcardconfig` para configurarla.

El siguiente paso es montar el disco duro de nuestro sistema. En este caso, vamos a
suponer que nuestra partición raíz es `/dev/sda1`. Así que ejecutamos::
    
    # mount /dev/sda1 /mnt

El comando de arriba montará la partición en el directorio `/mnt`. En este ejemplo
haremos una restauración completa. Primero eliminaremos todos los directorios existentes
en la partición. Por supuesto, si no haces una restaruación completa este paso no es necesario.

Para elmiinar los ficheros existentes y pasar a la restauración ejecutamos::

    # rm -rf /mnt/*

Instalaremos duplicity en caso de no tenerlo disponible::

    # apt-get update
    # apt-get install duplicity

Antes de hacer una restauración completa necesitamos restaurar
`/etc/passwd` y `/etc/group`. En caso contrario podemos tener problemas al
restaurar archivos con el propietario incorrecto. El problema se debe a
que *duplicity* almacena los nombres de usuario y grupo y no los valores
númericos. Así pues, tendremos problemas si restauramos ficheros en un
sistema en el que el nombre de usuario o grupo tienen distinto UID o GID.
Para evitar este problema sobreescribimos `/etc/passwd` y `/etc/group` en
el sistema de rescate. Ejecutamos::

    # duplicity restore --file-to-restore etc/passwd \
    # scp://backupuser@192.168.122.1 /etc/passwd --ssh-askpass --no-encryption --force

    # duplicity restore --file-to-restore etc/group \
    # scp://backupuser@192.168.122.1 /etc/group --ssh-askpass --no-encryption --force

.. warning::
    Si usamos *SCP*, tendremos que ejecutar `sudo ssh usuario@servvidor`para
    añadir el servidor remoto a la lista de servidores SSH conocidos. Si no se
    realiza esta operación, la copia de respaldo no podrá ser realizada ya que
    fallará la conexión con el servidor.

Ahora podemos proceder con la restauración completa ejecutando  *duplicity*
manualmente::

    # duplicity restore  scp://backupuser@192.168.122.1 /mnt/ --ssh-askpass --no-encryption --force

Por último debemos crear los directorios excluídos de la copia de
respaldo así como limpiar los directorios temporales::

    # mkdir -p /mnt/dev
    # mkdir -p /mnt/sys
    # mkdir -p /mnt/proc
    # rm -fr /mnt/var/run/*
    # rm -fr /mnt/var/lock/*


El proceso de restauración ha finalizado y podemos reiniciar el sistema
original.

.. _conf-backup-ref:

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
