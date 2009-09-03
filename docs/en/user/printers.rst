.. _printers-ref:

Servicio de compartición de impresoras
**************************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>,
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>,
                   Javier Uruen <juruen@ebox-platform.com>

Para compartir una impresora de nuestra red, permitiendo o denegando
el acceso a usuarios y grupos para su uso, debemos tener accesibilidad
a dicha impresora desde la máquina que contenga eBox ya por conexión
directa, puerto paralelo o USB [#]_, o a través de la red local. Además
debemos conocer información relativa al fabricante, modelo y
controlador de la impresora si se quiere obtener un funcionamiento
correcto.

.. [#] *Universal Serial Bus* (USB) es un bus serie estándar para
       comunicación de dispositivos con la computadora.

Una vez tenemos todos los datos previos, se puede añadir una impresora
a través de :menuselection:`Impresoras --> Añadir Impresora`. Ahí se
sigue un asistente en el que se irán introduciendo los datos
necesarios para su incursión en función de los datos entrantes.

En primer lugar, se establece un nombre significativo para la
impresora y se configura el método de conexión. Este método depende del modelo
de impresora y de cómo esté conectada a nuestra red. Los siguiente métodos de
conexión están soportados por eBox:

Puerto paralelo:
  Una impresora conectada al servidor eBox mediante el puerto paralelo del mismo.
USB:
  Una impresora conectada al servidor eBox mediante el puerto USB.
*AppSocket*:
  Una impresora remota de red que se comunica con el protocolo
  *AppSocket*. A este protocolo también se le conoce con el nombre de
  *JetDirect*.
IPP:
  Una impresora remota que usa el protocolo IPP [#]_ para comunicarse.
LPD:
  Una impresora remota que usa el protocolo LPD [#]_ para comunicarse.
Samba:
   Una impresora remota a la que se puede acceder como recurso compartido de red
   bajo Samba o Windows.

.. [#] *Internet Printing Protocol* (IPP) es un protocolo de red para
       la impresión remota y para la gestión de cola de
       impresión. Más información en :rfc:`2910`.

.. [#] *Line Printer Daemon protocol* (LPD) son un conjunto de
       programas que permiten la impresión remota y el envío de
       trabajos usando *spooling* a las impresoras para los sistemas
       *Unix*. Más información en :rfc:`1179`.

.. image:: images/printers/12-printer.png
   :scale: 60
   :align: left

En función del método seleccionado, se deben configurar los parámetros
de la conexión. Por ejemplo, para una impresora en red, se debe establecer
la dirección IP y el puerto de escucha de la misma como muestra la
imagen.

.. image:: images/printers/12-printer1.png
   :scale: 60
   :align: left

Posteriormente, en los siguientes cuatro pasos se debe delimitar qué
controlador de impresora debe usar eBox para transmitir los datos a
imprimir, estableciendo el fabricante, modelo, controlador de
impresora a utilizar y sus parámetros de configuración.

.. image:: images/printers/12-printer2.png
   :scale: 60
   :align: left
.. image:: images/printers/12-printer3.png
   :scale: 60
   :align: left
.. image:: images/printers/12-printer4.png
   :scale: 60
   :align: left
.. image:: images/printers/12-printer5.png
   :scale: 60
   :align: left

Una vez finalizado el asistente, ya tenemos la impresora configurada.
Por tanto, podremos observar qué trabajos de impresión están pendientes
o en proceso. También tendremos la posibilidad de modificar alguno de
los parámetros introducidos en el asistente a través de
:menuselection:`Impresoras --> Gestionar impresoras`.

Las impresoras gestionadas por eBox son accesibles mediante el
protocolo Samba. Adicionalmente podremos habilitar el demonio de
impresión CUPS [#]_ que hará accesibles las impresoras mediante IPP.

.. [#] *Common Unix Printing System* (CUPS) es un sistema modular de
       impresión para sistemas Unix que permiten a una máquina actuar
       de servidor de impresión, lo cual permite aceptar trabajos de
       impresión, su procesamiento y envío a la impresora adecuada.

.. _cups-img-ref:

.. figure:: images/printers/16-manage-printers.png
   :scale: 80
   :align: center
   :alt: Gestión de impresoras
   
   Gestión de impresoras

Si una impresora no está soportada por eBox, es decir, que eBox no
dispone de los controladores necesarios para gestionar dicha
impresora, hay que usar CUPS en su defecto. Para añadir una impresora
por CUPS hay que habilitar su demonio de impresión como se muestra en
la figura :ref:`cups-img-ref` con :guilabel:`Habilitar CUPS`. Una vez
se ha habilitado, se puede configurar a través de::

  http://direccion_ebox:631

Una vez añadida la impresora a través de CUPS, eBox es capaz de
exportarla usando el protocolo de Samba para ello.

Una vez habilitamos el servicio y salvamos cambios podemos comenzar a
permitir el acceso a dichos recursos a través de la edición del grupo
o del usuario (:menuselection:`Grupos --> Editar Grupo --> Impresoras`
o :menuselection:`Usuarios --> Editar Usuario --> Impresoras`).

.. image:: images/printers/13-printer-user.png
   :scale: 80
   :align: center

.. include:: printers-exercises.rst
