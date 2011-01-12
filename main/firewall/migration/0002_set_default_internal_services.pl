#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
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

#	Migration between gconf data version 0 to 1
#
#	In version 1, a new model has been created to store firewall rules and it
#	lives in another module called services. In previous versions
#	servies were stored in firewall.
#
#	This migration script tries to populate the services model with the
#	stored services in firewall
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Data::Dumper;
use EBox::Model::ModelManager;
use Socket;
use Error qw(:try);




sub _setDefaultInternalServices
{
    my ($self) = @_;

    my $fw = $self->{gconfmodule};

    # the setInternalService doesn'tadd anything if there is already a rule so
    # this safe with previous version that used the onInstall method
    $fw->setInternalService('eBox administration', 'accept');
    $fw->setInternalService('ssh', 'accept');

    $fw->saveConfigRecursive();
}

sub runGConf
{
    my ($self) = @_;

    $self->_setDefaultInternalServices();
}

EBox::init();

my $fwMod = EBox::Global->modInstance('firewall');
my $migration = new EBox::Migration(
				    'gconfmodule' => $fwMod,
				    'version' => 2,
				   );

$migration->execute();
