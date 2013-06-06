#!/bin/bash -x
HOST=192.168.100.108
PASS=foobar

copiar () {
    sshpass -p $PASS scp  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $1 root\@$HOST:$2
}



for i in login public tableorderer jquery-ui
do
    copiar extra/css/$i.css.mas /usr/share/zentyal/stubs/css/
done

copiar www/default.theme /usr/share/zentyal/www/
copiar 'www/css/jquery-ui/images/*' /usr/share/zentyal/www/css/jquery-ui/images/
copiar 'www/images/*' /usr/share/zentyal/www/images/
copiar 'src/templates/progress.mas' /usr/share/zentyal/templates/progress.mas
copiar '../software/www/software/images/*' /usr/share/zentyal/www/software/images/

sshpass -p $PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root\@$HOST /etc/init.d/zentyal webadmin restart
