#!/usr/bin/perl

# Copyright (C) 2011 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Sudo;
use Error qw(:try);

use constant APPARMOR_PROFILE => '/etc/apparmor.d/usr.sbin.dhcpd3';
use constant APPARMOR_SERVICE => '/etc/init.d/apparmor';
use constant OLD_APPARMOR_PROFILE => '/etc/apparmor.d/usr.sbin.dhcpd3.zentyal';

sub runGConf
{
    my ($self) = @_;

    my $dhcpMod = $self->{gconfmodule};

    try {
        if ( -e OLD_APPARMOR_PROFILE ) {
            EBox::Sudo::root('rm -f ' . OLD_APPARMOR_PROFILE);
        }

        if ( $dhcpMod->isEnabled() and (-x APPARMOR_SERVICE )) {
            $dhcpMod->writeConfFile(APPARMOR_PROFILE,
                                    'dhcp/apparmor-dhcpd.profile.mas',
                                    [ ( 'keysFile' => $dhcpMod->_keysFile(),
                                        'confDir'  => $dhcpMod->IncludeDir() ) ]);
            EBox::Sudo::root(APPARMOR_SERVICE . ' restart');
        }
    } otherwise { };

}

EBox::init();

my $dhcpMod = EBox::Global->modInstance('dhcp');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $dhcpMod,
    'version' => 6
);
$migration->execute();

