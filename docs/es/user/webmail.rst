.. _webmail-ref:

Servicio de correo web
***********************

El **servicio de correo web** permite a los usuarios leer y enviar correo a través
de un interfaz web ofrecida por el servidor de correo.

Sus principales ventajas son que el usuario no tiene que configurar
nada. Y que puede acceder a su correo desde cualquier navegador *web*
que pueda alcanzar al servidor. Sus desventajas son que la experiencia
de usuario suele ser más pobre que con un programa de correo de
escritorio y que se debe permitir el acceso web al servidor de
correo. Además, incrementa la carga del servidor para mostrar los
mensajes de correo, este trabajo se realiza en el cliente con el
*software* tradicional de gestión de correo electrónico.

eBox usa **Roundcube** para implementar este servicio [#]_.

.. [#] Roundcube webmail http://roundcube.net/ .

Configurando el correo web en eBox
----------------------------------

El **servicio de correo web** se puede habilitar de la misma manera
que cualquier otro servicio de eBox. Sin embargo, requiere que el
módulo de **correo** esté configurado para usar IMAP, IMAPS o ambos
además de tener el módulo **webserver** habilitado. Si no lo está, el
servicio rehusará activarse.

.. [#] La configuración de correo en eBox se explica de manera extensa
       en la sección :ref:`mail-service-ref` y el módulo *web* se
       explica en la sección :ref:`web-section-ref`.

Opciones del correo web
~~~~~~~~~~~~~~~~~~~~~~~

Podemos acceder a las opciones pulsando en la sección
:menuselection:`Webmail` de menú izquierdo. Se puede establecer el
titulo que usará el correo *web* para identificarse, este titulo se
mostrará en la pantalla de entrada y en los títulos HTML de pagina.

.. image:: images/webmail/general-settings.png
   :scale: 80



Entrar en el correo web
~~~~~~~~~~~~~~~~~~~~~~~

Para entrar en el correo *web*, primero necesitaremos que el tráfico
HTTP desde la dirección usada para conectar esté permitido por el
cortafuegos. La pantalla de entrada del correo web está disponible en
`http://[direccion del servidor]/webmail` desde el navegador. A
continuación, se debe introducir su dirección de correo y su
contraseña. Los alias no funcionarán, por tanto
se debe usar la dirección real.

.. image:: images/webmail/roundcube-login.png
   :scale: 70


Filtros SIEVE
~~~~~~~~~~~~~

El **correo web** también incluye una interfaz para administrar
filtros SIEVE. Esta interfaz sólo está disponible si el protocolo
*ManageSIEVE* está activo en el servicio de correo.

.. [#] Visita la sección :ref:`sieve-sec-ref` para obtener más información.


