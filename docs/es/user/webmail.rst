.. webmail-ref:

Servicio de correo web
***********************

El servicio de correo web permite a los usuarios leer y enviar correo a través
de una interface web ofrecida por el servidor de correo.

Tiene las ventajas de que el usuario no tiene que configurar nada y que puede
acceder a su correo desde cualquier navegador web que pueda alcanzar al
servidor. Sus desventajas es que la experiencia de usuario suele ser mas pobre
que con un programa de correo de escritorio y que se debe permitir el acceso web
al servidor de correo. Además incrementa la carga del servidor mas que un
programa de correo en el lado del servidor.

eBox usa Roundcube para implementar este servicio [#]_.


.. [#] Roundcube webmail http://roundcube.net/ .



Activando el servicio de correo web
------------------------------------

El servicio de correo web se puede activar de la misma manera que cualquier otro
servicio de eBox. Sin embargo, requiere que el servicio de correo este
configurado para usar IMAP, IMAPS o ambos. Si no lo esta, el servicio rehusara activarse.


Opciones del correo web
-----------------------

Podemos acceder a las opciones pulsando en la sección :menuselection:`Webmail`
de menú izquierdo. En el formulario de opciones podemos establecer el titulo que
usara el correo web para identificarse, este titulo se mostrara en la pantalla
de login y en los títulos de pagina.



Entrar en el correo web
-------------------------

Para entrar en el correo web primero necesitaremos que el trafico HTTP desde la
dirección usada para conectar este permitido por el cortafuegos.

Para acceder a la pantalla de entrada del correo web, el usuario debe apuntar
su navegador web hacia la dirección `http://[direccion del servidor]/webmail`. 

A continuación debe introducir su dirección de correo y su contraseña. Debe usar
su dirección real, un alias no funcionara.


Filtros SIEVE 
--------------

El correo web también incluye una interface para administrar filtros SIEVE. Esta
interfaz solo esta disponible si el protocolo ManageSIEVE esta activo en el
servicio de correo.

