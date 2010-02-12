.. _filesharing-chapter-ref:

Servicio de compartición de ficheros y de autenticación
*******************************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Javier Uruen <juruen@ebox-platform.com>

Compartición de ficheros
========================

La **compartición de ficheros** se realiza a través de un sistema de ficheros en
red. Los principales sistemas existentes para ello son *Network File
System* (NFS), de Sun Microsystems, que fue el primero en crearse, *Andrew File
System* (AFS) y *Common Internet File System* (CIFS) también conocido como
*Server Message Block* (SMB).

A los clientes se les da la abstracción de estar haciendo operaciones
(creación, lectura, escritura) sobre ficheros en un medio de
almacenamiento de la misma máquina. Sin embargo, esta información puede estar
dispersa en diferentes lugares, siendo por tanto transparente en cuanto a su
localización. Idealmente, el cliente no debería saber si el fichero se almacena en
la propia máquina o se dispersa por la red. En realidad, eso no es posible
debido a los retardos de la red y las cuestiones relacionadas con la
actualización concurrente de ficheros comunes y que no deberían interferir
entre ellas.

SMB/CIFS y su implementación Linux Samba
========================================

El SMB (*Server Message Block*) o CIFS (*Common Internet File System*) se usa
para compartir el acceso a ficheros, impresoras, puertos serie y otra serie de
comunicaciones entre nodos en una red local. También ofrece mecanismos de
autenticación entre procesos. Se usa principalmente entre ordenadores
*Windows*, sin embargo, existen implementaciones en otros sistemas operativos
como GNU/Linux a través de Samba que implementa los protocolos de los
sistemas *Windows* utilizando ingeniería inversa [#]_.

.. [#] La ingeniería inversa trata de averiguar los protocolos de
       comunicación usando para ello únicamente sus mensajes.

Ante el auge de otros sistemas de compartición de ficheros, Microsoft decidió
renombrar SMB a CIFS añadiendo nuevas características como enlaces simbólicos y
fuertes, mayores tamaños para los ficheros y evitar el uso de NetBIOS [#]_
sobre el que SMB se basa.

.. [#] **NetBIOS** (*Network Basic Input/Output System*): API que permite la
         comunicación en una red de área local entre ordenadores diferentes
         dando a cada máquina un nombre NetBIOS y una dirección IP
         correspondiente a un (posiblemente diferente) nombre de máquina.

Primary Domain Controller (PDC)
===============================

Un **PDC** es un servidor de dominios de versiones *Windows NT* previas a
*Windows 2000*. Un dominio, según este entorno, es un sistema que permite el
acceso restringido a una serie de recursos con el uso de un única combinación
nombre de usuario y contraseña. Por tanto, es posible utilizarlo para permitir
la entrada en el sistema con control de acceso remoto. PDC también ha sido
recreado por Samba dentro del sistema de autenticación de SMB. En las versiones
más modernas de *Windows* ha pasado a denominarse simplemente *Domain Controller*.

.. _ebox-samba-ref:

eBox como servidor de ficheros
==============================

Nosotros nos vamos a aprovechar de la implementación de SMB/CIFS para Linux
usando **Samba** como servidor de ficheros y de autenticación de sistemas
operativos *Windows* en eBox.

Los servicios de compartición de ficheros están activos cuando el
módulo de **Compartición de ficheros** esté activo, sin importar si la
función de :guilabel:`PDC` esté activa.

Con eBox la compartición de ficheros está integrada con los usuarios y
grupos. De tal manera que cada usuario tendrá su directorio personal y
cada grupo puede tener un directorio compartido para todos sus
usuarios.

El directorio personal de cada usuario es compartido automáticamente y solo puede
ser accedido por el correspondiente usuario.

.. FIXME: Show only the directory to share

.. image:: images/filesharing/10-share-group.png
   :scale: 80

También se puede crear un directorio compartido para un grupo desde
:menuselection:`Grupos --> Editar grupo`. Todos los miembros del grupo
tendrán acceso a ese directorio y podrán leer o escribir los ficheros y
directorios dentro de dicho directorio compartido.

.. FIXME: Update the shot

.. image:: images/filesharing/06-sharing.png
   :scale: 80

Ir a :menuselection:`Compartir Ficheros --> Configuración general`
para configurar los parámetros generales del servicio de compartición
de ficheros. Establecemos como :guilabel:`dominio` dónde se trabajará
dentro de la red local dentro de *Windows*, y como :guilabel:`nombre
NetBIOS` el nombre que identificará a eBox dentro de la red
*Windows*. Se le puede dar una :guilabel:`descripción` larga para
describir el dominio. Además se puede establecer de manera opcional un
:guilabel:`límite de cuota`. Con el :guilabel:`Grupo Samba` se puede
opcionalmente configurar un grupo exclusivo en el que sus usuarios
tenga cuenta de compartición de ficheros en vez de todos los usuarios,
la sincronización se hace cada hora.

Para crear un directorio compartido, se accede a
:menuselection:`Compartir Ficheros --> Directorios compartidos`
y se pulsa :guilabel:`Añadir nuevo`.

.. image:: images/filesharing/07-share-add.png
   :scale: 80

Habilitado:
  Lo dejaremos marcado si queremos que este directorio esté
  compartido. Podemos deshabilitarlo para dejar de compartirlo
  manteniendo la configuración.

Nombre del directorio compartido:
  El nombre por el que será conocido el directorio compartido.

Ruta del directorio compartido:
  Ruta del directorio a compartir. Se puede crear un subdirectorio dentro del
  directorio de eBox */home/samba/shares*, o usar directamente una
  ruta existente del sistema si se elige :guilabel:`Ruta del sistema
  de ficheros`.

Comentario:
  Una descripción más extensa del directorio compartido para facilitar
  la gestión de los elementos compartidos.

.. image:: images/filesharing/08-shares.png
   :scale: 80

Desde la lista de directorios compartidos podemos editar el
:guilabel:`control de acceso`. Allí, pulsando en :guilabel:`Añadir
nuevo`, podemos asignar permisos de lectura, lectura y escritura o
administración a un usuario o a un grupo. Si un usuario es
administrador de un directorio compartido podrá leer, escribir y
borrar ficheros de cualquier otro usuario dentro de dicho directorio.

.. image:: images/filesharing/09-share-acl.png
   :scale: 80

También se puede crear un directorio compartido para un grupo desde
:menuselection:`Usuarios y Grupos --> Grupos`. Todos los miembros del
grupo tendrán acceso a ese directorio y podrán leer o escribir los
ficheros y directorios dentro de dicho directorio compartido.

Si se quieren almacenar los ficheros borrados dentro de un directorio
especial llamado `RecycleBin`, se puede marcar
la casilla :guilabel:`Habilitar Papelera de Reciclaje` dentro de
:menuselection:`Compartir ficheros --> Papelera de Reciclaje`. Si no se
desea activar la papelera para todos los recursos compartidos, se pueden
añadir excepciones en la sección :guilabel:`Recursos excluidos de la
Papelera de Reciclaje`. También se pueden modificar algunos otros valores
por defecto para esta característica, como por ejemplo el nombre del
directorio, editando el fichero `/etc/ebox/80samba.conf`.

.. image:: images/filesharing/recycle-bin.png
   :scale: 80

En :menuselection:`Compartir ficheros --> Antivirus` existe también una
casilla para habilitar o deshabilitar la búsqueda de virus en los recursos
compartidos y la posibilidad de añadir excepciones para aquellos en los que
no se desee buscar. Nótese que para acceder la configuración del antivirus
para el módulo de compartir ficheros es requisito tener instalado el paquete
**samba-vscan** en el sistema. El módulo **antivirus** de eBox debe estar así
mismo instalado y habilitado.

Configuración de clientes SMB/CIFS
==================================

Una vez tenemos el servicio ejecutándose podemos compartir ficheros a través de
*Windows* o GNU/Linux.

Cliente Windows
---------------

  A través de :menuselection:`Mis sitios de red --> Toda la
  red`. Encontramos el dominio que hemos elegido y después aparecerá
  la máquina servidora con el nombre seleccionado y podremos ver sus
  recursos compartidos:

  .. image:: images/filesharing/14-windows-shares.png
     :scale: 70
     :align: center

Cliente Linux
-------------

  1. Konqueror (KDE)

     En Konqueror basta con poner en la barra de búsqueda ``smb://`` para ver
     la red de *Windows* en la que podemos encontrar el dominio especificado:

     .. image:: images/filesharing/14-kde-shares.png
        :scale: 70
        :align: center

  2. Nautilus (Gnome)

     En Nautilus vamos a :menuselection:`Lugares --> Servidores de Red
     --> Red de Windows`, ahí encontramos nuestro dominio y dentro del
     mismo el servidor eBox donde compartir los recursos.

     .. image:: images/filesharing/14-gnome-shares.png
        :scale: 70
        :align: center

     Hay que tener en cuenta que los directorios personales de los
     usuarios no se muestran en la navegación y para entrar en ellos
     se debe hacer directamente escribiendo la dirección en la barra
     de búsqueda. Por ejemplo, para acceder al directorio personal del
     usuario *pedro*, debería introducir la siguiente dirección::

       smb://<ip_de_ebox>/pedro

  3. Smbclient

     Además de las interfaces gráficas, disponemos un cliente de línea de
     comandos que funciona de manera similar a un cliente FTP, con manejo de
     sesiones. Permite la descarga y subida de ficheros, recoger información
     sobre ficheros y directorios, etc. Un ejemplo de sesión puede ser el
     siguiente::

       $ smbclient -U joe //192.168.45.90/joe
       > get ejemplo
       > put eaea
       > ls
       > exit
       $ smbclient -U joe -L //192.168.45.90/
       Domain=[eBox] OS=[Unix] Server=[Samba 3.0.14a-Debian]
       Sharename       Type      Comment
       ---------       ----      -------
       _foo            Disk
       _mafia          Disk
       hp              Printer
       br              Printer
       IPC$            IPC       IPC Service (eBox Samba Server)
       ADMIN$          IPC       IPC Service (eBox Samba Server)
       joe         Disk      Home Directories
       Domain=[eBox] OS=[Unix] Server=[Samba 3.0.14a-Debian]
       Server               Comment
       ---------            -------
       DME01                PC Verificaci
       eBox-SMB3            eBox Samba Server
       WARP-T42
       Workgroup            Master
       ---------            -------
       eBox                 eBox-SMB3
       GRUPO_TRABAJO        POINT
       INICIOMS             WARHOL
       MSHOME               SHINNER
       WARP                 WARP-JIMBO

eBox como un servidor de autenticación
======================================

Para aprovechar las posibilidades del PDC como servidor de
autenticación y su implementación **Samba** para GNU/Linux debemos
marcar la casilla :guilabel:`Habilitar PDC` a través de
:menuselection:`Compartir ficheros --> Configuración General`.

.. FIXME: Updte the shot

.. image:: images/filesharing/06-pdc-enabled.png
   :scale: 80

Si la opción :guilabel:`Perfiles Móviles` está activada, el servidor PDC no
sólo realizará la autenticación, sino que también almacenará los
perfiles de cada usuario. Estos perfiles contienen toda la información
del usuario, como sus preferencias de *Windows*, sus cuentas de correo
de *Outlook*, o sus documentos.  Cuando un usuario inicie sesión,
recibirá del servidor PDC su perfil. De esta manera, el usuario
dispondrá de su entorno de trabajo en varios ordenadores. Hay que
tener en cuenta antes de activar esta opción que la información de los
usuarios puede ocupar varios GiB de información, el servidor PDC
necesitará espacio de disco suficiente. También se puede
configurar la :guilabel:`letra del disco` al que se conectará el
directorio personal del usuario tras autenticar contra el PDC en
Windows.

Es posible definir políticas para las contraseñas de
los usuarios a través de :menuselection:`Compartir ficheros -->
PDC`. Estas políticas suelen ser forzadas por la ley.

* :guilabel:`Longitud mínima de contraseña`.
* :guilabel:`Edad máxima de contraseña`. Dicha contraseña deberá
  renovarse tras superar los días configurados.
* :guilabel:`Forzar historial de contraseñas`. Esta opción forzará a
  almacenar un máximo de contraseñas tras modificarlas.

Estas políticas son únicamente aplicables cuando se cambia la
contraseña desde Windows con una máquina que está conectada a nuestro
dominio. De hecho, Windows forzará el cumplimiento de dicha política
al entrar en una máquina registrada en el dominio.

.. image:: images/filesharing/06-pdc-settings.png
   :scale: 80

Configuración de clientes PDC
=============================

Para poder configurar la autenticación PDC en una máquina, se necesita
utilizar una cuenta que tenga privilegios de administrador en el
servidor PDC. Esto se configura en :menuselection:`Usuarios y
Grupos--> Usuarios --> Cuenta de compartición de ficheros o de
PDC`. Adicionalmente, se puede establecer una :guilabel:`Cuota de
disco`.

.. image:: images/filesharing/11-share-user.png
   :scale: 80

Ahora vamos a otra máquina dentro de la misma red de área local (hay
que tener en cuenta que el protocolo SMB/CIFS funciona en modo
difusión total) con un *Windows* capaz de trabajar con CIFS
(Ej. *Windows XP Professional*). Allí, en :menuselection:`Mi PC -->
Propiedades`, lanzamos el asistente para asignar una *Id de red* a la
máquina. En cada pregunta se le da como nombre de usuario y contraseña
la de aquel usuario al que hemos dado privilegios de administrador, y
como dominio el nombre de dominio escrito en la configuración de
:menuselection:`Compartir Ficheros`. El nombre de la máquina puede ser
el mismo que estaba, siempre y cuando no colisione con el resto de
equipos a añadir al dominio. Tras finalizar el asistente, se debe
reiniciar la máquina.

Una vez hemos entrado con uno de los usuarios, podemos entrar en
:menuselection:`Mi PC` y aparecerá una partición de red con una cuota
determinada en la configuración de eBox.

.. image:: images/filesharing/15-windows-partition.png
   :scale: 80
   :align: center

.. include:: filesharing-exercises.rst
