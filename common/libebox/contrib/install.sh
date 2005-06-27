#!/bin/sh

install_ebox() {
	cd ebox/trunk
	./autogen.sh --localstatedir=/var
	sudo make install || exit
	sudo mkdir /var/lib/ebox/tmp
	sudo mkdir /var/lib/ebox/log
	sudo cp conf/.gconf.path /var/lib/ebox
	sudo cp tools/ebox /etc/init.d
	make maintainer-clean
	rmdir config
	svn revert po/es.po
	cd ../..
}

install_module() {
        cd $1/trunk
        ./autogen.sh
        su -c "make install" || exit
        make maintainer-clean
        svn revert po/es.po
        cd ../..
}

install_ebox
install_module squid
install_module dhcp

sudo chown -R ebox.ebox /var/lib/ebox

/etc/init.d/apache-perl stop
sleep 1
/etc/init.d/apache-perl start
