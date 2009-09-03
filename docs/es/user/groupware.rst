Servicio de *groupware*
***********************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>

El **groupware**, también conocido como *software* colaborativo, es el conjunto
de aplicaciones que integran el trabajo de distintos usuarios en proyectos
comunes. Cada usuario puede conectarse al sistema desde distintas estaciones
de trabajo de la red local o también desde cualquier punto del mundo a
través de Internet.

Algunas de las funciones más destacadas de las herramientas de *groupware*
son:

* Comunicación entre los usuarios: correo, salas de *chat*, etc.
* Compartición de información: calendarios compartidos, listas de tareas,
  libretas de direcciones comunes, base de conocimiento,
  compartición de ficheros, noticias, etc.
* Gestión de proyectos, recursos, tiempo, *bugtracking*, etc.

Existen en el mercado una gran cantidad de soluciones de
*groupware*. Entre las opciones que nos ofrece el Software Libre, una
de las más populares es eGroupware [#]_ y es la seleccionada para eBox
Platform para implementar esta funcionalidad tan importante en el
ámbito empresarial.

.. [#] **eGroupware**: *An enterprise ready groupware software for your
       network* http://www.egroupware.org

Con eBox Platform la puesta a punto de eGroupware es muy sencilla. El
objetivo es que el usuario no tenga que acceder a la configuración
tradicional que ofrece eGroupware y pueda realizarlo prácticamente
todo desde el interfaz de eBox, salvo que necesite alguna
personalización avanzada. De hecho la contraseña para la configuración
de eGroupware es auto-generada [#]_ por eBox y el administrador debería
usarla bajo su responsabilidad dado que si realiza una acción
inapropiada el módulo podría quedar mal configurado y en un estado inestable.

.. [#] Nota para usuarios avanzados de eGroupware: La contraseña se
       encuentra en el fichero `/var/lib/ebox/conf/ebox-egroupware.passwd` y
       los nombres de usuario son 'admin' y 'ebox' para la configuración del
       encabezado y del dominio respectivamente.


Configuración de servicio de groupware con eBox
===============================================

La mayor parte de la configuración de eGroupware se realiza
automáticamente al habilitar el módulo y guardar los cambios. Sin
requerir ninguna intervención adicional del usuario, eGroupware estará
en funcionamiento integrado con el servicio de directorio (LDAP) de
eBox. Es decir, todos los usuarios que sean añadidos en eBox a partir
de ese momento podrán iniciar sesión en eGroupware sin requerir
ninguna otra acción especial.

Adicionalmente, podemos integrar el servicio de correo web (*webmail*)
que eGroupware nos proporciona con el módulo de **correo** de eBox.
Para ello lo único que hay que hacer es seleccionar un dominio
virtual previamente existente y tener habilitado el servicio de
recepción de correo IMAP. Las instrucciones relativas a la creación de
un dominio de correo y configuración del servicio IMAP se explican con
detenimiento en el capítulo :ref:`mail-service-ref`.

Para la selección del dominio que usará eGroupware accederemos al menú
:menuselection:`Groupware` y a la pestaña :guilabel:`Dominio Virtual de Correo`.
La interfaz se muestra en la siguiente imagen, sólo tenemos que seleccionar
el dominio deseado y pulsar el botón :guilabel:`Cambiar`. Aunque como de
costumbre esto no tendrá efecto hasta que no pulsemos el botón
:guilabel:`Guardar Cambios`.

.. image:: images/groupware/egw-vdomain.png
   :scale: 80
   :align: center

Para que nuestros usuarios puedan utilizar el servicio de correo tendrán que
tener creadas sus respectivas cuentas en el mismo. En la imagen que se muestra
a continuación (:menuselection:`Usuarios --> Editar Usuario`) podemos ver que
en la configuración de eGroupware se muestra un aviso indicando cuál debe
ser el nombre de la cuenta de correo para que pueda ser usada desde eGroupware.

.. image:: images/groupware/egw-edit-user.png
   :scale: 80
   :align: center

eGroupware se compone de varias aplicaciones, en eBox podemos editar
los permisos de acceso de cada usuario asignándole una plantilla de permisos,
como se puede ver en la imagen anterior. Disponemos de una plantilla de
permisos creada por defecto pero podemos definir otras personalizadas.

La plantilla de permisos por defecto es útil si queremos que la mayoría de
los usuarios del sistema tengan los mismos permisos, de modo que cuando
creemos un nuevo usuario no tengamos que preocuparnos de asignarle permisos,
ya que éstos serán asignados automáticamente.

Para editar la plantilla por defecto accederemos al menú
:menuselection:`Groupware` y a la pestaña
:menuselection:`Aplicaciones predeterminadas`, como se muestra en la imagen.

.. image:: images/groupware/egw-default-apps.png
   :scale: 80
   :align: center

Para grupos reducidos de usuarios como es el caso de los administradores,
podemos definir una plantilla de permisos personalizada y aplicarla
manualmente a dichos usuarios.

Para definir una nueva plantilla debemos acceder a la pestaña
:guilabel:`Plantillas definidas por el usuario` del menú
:menuselection:`Groupware` y pulsar en :guilabel:`Añadir nueva`. Una vez
introducido el nombre deseado aparecerá en la tabla y podremos editar las
aplicaciones pulsando en :guilabel:`Aplicaciones permitidas`, de forma
análoga a como se hace con la plantilla por defecto.

.. image:: images/groupware/egw-user-templates.png
   :scale: 80
   :align: center

Hay que tener en cuenta que si modificamos la plantilla de permisos por
defecto, los cambios sólo serán aplicados a los usuarios que sean creados a
partir de ese momento. No se aplicarán de manera retroactiva a los usuarios
creados previamente. Lo mismo ocurre con las plantillas definidas por el
usuario, si existiesen usuarios con esa plantilla aplicada habría que editar
las propiedades del usuario y aplicarle nuevamente la misma plantilla
después de modificarla.

Finalmente, cuando hayamos configurado todo, podemos acceder a eGroupware a
través de la dirección `http://<ip_de_ebox>/egroupware` utilizando el
usuario y contraseña definidos en la interfaz de eBox.

.. image:: images/groupware/egw-login.png
   :scale: 80
   :align: center

El manejo de eGroupware está fuera del alcance de este manual, para
cualquier duda se debe consultar el manual de usuario oficial de eGroupware.
Este se encuentra disponible en Internet en su página oficial y también está
enlazado desde la propia aplicación una vez que estamos dentro.

Ejemplo práctico
^^^^^^^^^^^^^^^^
Habilitar el módulo **Groupware** y comprobar su integración con el correo.

#. **Acción:**
   Acceder a eBox, entrar en :menuselection:`Estado del módulo` y
   activa el módulo :guilabel:`Groupware`, para ello marca su casilla en la
   columna :guilabel:`Estado`. Nos informa de que se modificará la
   configuración de eGroupware. Permitir la operación pulsando el botón
   :guilabel:`Aceptar`. Asegurarse de que se han habilitado previamiente los
   módulos de los que depende (Correo, Webserver, Usuarios...).

   Efecto:
     Se ha activado el botón :guilabel:`Guardar Cambios`.

#. **Acción:**
   Configurar un dominio virtual de correo como se muestra en el ejemplo
   :ref:`mail-conf-exercise-ref`. En dicho ejemplo también se añade un usuario
   con su cuenta de correo correspondiente. No son necesarios los pasos de
   ese ejemplo relativos a objetos o políticas de reenvío. Realizar sólo
   hasta el paso en que se añade el usuario.

   Efecto:
     El usuario creado tiene una cuenta de correo válida.

#. **Acción:**
   Acceder al menú :menuselection:`Correo --> General` y en la pestaña
   :guilabel:`Opciones del servidor de correo` activar la casilla
   :guilabel:`Servicio IMAP habilitado` y pulsar :guilabel:`Cambiar`.

   Efecto:
     El cambio se ha guardado temporalmente pero no será efectivo hasta que
     se guarden los cambios.

#. **Acción:**
   Acceder al menú :menuselection:`Groupware` y en la pestaña
   :guilabel:`Dominio Virtual de Correo` seleccionar el dominio
   creado anteriormente y pulsar :guilabel:`Cambiar`.

   Efecto:
     El cambio se ha guardado temporalmente pero no será efectivo hasta que
     se guarden los cambios.

#. **Acción:**
   Guardar los cambios.

   Efecto:
     eBox muestra el progreso mientras aplica los cambios. Una vez que ha
     terminado lo muestra.

     A partir de ahora eGroupware se encuentra configurado correctamente
     para integrarse con nuestro servidor IMAP.

#. **Acción:**
   Acceder a la interfaz de eGroupware (http://<ip_de_ebox>/egroupware) con
   el usuario que hemos creado anteriormente. Acceder a la aplicación de
   correo electrónico de eGroupware y enviar un correo a nuestra propia
   dirección.

   Efecto:
     Recibiremos el correo recién enviado en nuestro buzón de entrada.

.. include:: groupware-exercises.rst
