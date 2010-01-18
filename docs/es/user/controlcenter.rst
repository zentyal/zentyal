Cliente del Centro de Control
*****************************

.. sectionauthor:: Enrique J. Hernández <ejhernandez@ebox-platform.com>

**eBox Control Center** es una solución tolerante a fallos que permite
la monitorización en tiempo real y la administración de múltiples
instalaciones de eBox de un modo centralizado. Incluye características
como administración segura, centralizada y remota de grupos de eBox,
copias de seguridad de configuración automáticas remotas,
monitorización de red e informes personalizados. [#]_

.. [#] http://www.ebox-technologies.com/products/controlcenter/

A continuación se describe la configuración del lado del cliente con
el Centro de Control.

Subscribir eBox al Centro de Control
------------------------------------

Para configurar eBox para suscribirse al Centro de Control, debes
instalar el paquete `ebox-remoteservices` que se instala por defecto
si usas el instalador de eBox. Además, la conexión a *Internet* debe
estar disponible. Una vez esté todo preparado, ve a
:menuselection:`Centro de Control` y rellena los siguientes campos:

Nombre de Usuario o Dirección de Correo:
  Se debe establecer el nombre de usuario o la dirección de correo que
  se usa para entrar en la página *Web* del Centro de Control.

Contraseña:
  Es la misma contraseña que se usa para entrar en la *Web* del Centro
  de Control.

Nombre de eBox:
  Es el nombre único que se usará para esta eBox desde el Centro de
  Control. Este nombre se muestra en el panel de control y debe ser un
  nombre de dominio válido. Cada eBox debería tener un nombre
  diferente, si dos eBoxes tiene el mismo nombre para conectarse al
  Centro de Control, entonces sólo una de ellas se podrá conectar.

.. figure:: images/controlcenter/01-subscribe.png
   :scale: 70
   :alt: Subscribiendo eBox al Centro de Control
   :align: center

   Subscribiendo eBox al Centro de Control

Tras introducir los datos, la subscripción tardará alrededor de un
minuto. Nos tenemos que asegurar que tras terminar el proceso de
subscripción se guardan los cambios. Durante el proceso se habilita
una conexión VPN entre eBox y el Centro de Control, por tanto, se
habilitará el módulo **vpn**. [#]_

.. [#] Para más información sobre VPN, ir a la sección :ref:`vpn-ref`.

.. figure:: images/controlcenter/02-after-subscribe.png
   :scale: 70
   :alt: Tras suscribirse eBox al Centro de Control
   :align: center

   Tras suscribirse eBox al Centro de Control

Si la conexión funcionó correctamente con el Centro de Control,
entonces un *widget* aparecerá en el *dashboard* indicando que la
conexión se estableció correctamente. 

.. figure:: images/controlcenter/03-widget.png
   :scale: 70
   :alt: *Widget* de conexión al Centro de Control
   :align: center

   *Widget* de conexión al Centro de Control

Copia de seguridad de la configuración al Centro de Control
-----------------------------------------------------------

Una de las características usando el Centro de Control es la copia de
seguridad automática de la configuración de eBox [#]_ que se almacena
en el Centro de Control. Esta copia se hace diariamente si hay algún
cambio en la configuración de eBox. Ir a :menuselection:`Sistema -- >
Backup --> Backup remoto` para comprobar que las copias se han hecho
correctamente. Puedes realizar una copia de seguridad de la
configuración de manera manual si quieres estar seguro que tu última
configuración está almacenada en el Centro de Control.

.. [#] Las copias de seguridad de la configuración en eBox se explican
       en la sección :ref:`conf-backup-ref`.

.. figure:: images/controlcenter/04-remote-backup.png
   :scale: 70
   :alt: Copia de seguridad de la configuración remota 
   :align: center
   
   Copia de seguridad de la configuración remota

Se pueden restaurar, descargar o borrar copias de seguridad de la
configuración que se almacenan en el Centro de Control. Además para
mejorar el proceso de restauración ante un desastre, se puede
restaurar o descargar la configuración almacenada de uno del resto de
eBox suscritos al Centro de Control usando tu par usuario/correo
electrónico y contraseña. Para hacer eso, ir a la pestaña
:menuselection:`Sistema --> Backup --> Backup remoto de otras máquinas
suscritas`.

.. figure:: images/controlcenter/05-remote-backup-other.png
   :scale: 70
   :alt: Copia de seguridad de la configuración remota desde otra máquina suscrita
   :align: center
   
   Copia de seguridad de la configuración remota desde otra máquina suscrita

