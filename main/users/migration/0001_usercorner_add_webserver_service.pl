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

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

sub _availablePort
{
  my ($self) = @_;

  my $firewallMod = EBox::Global->modInstance('firewall');

  my $port = 8888; # Default port = 8888

  # Check port availability
  my $available = 0;
  do {
   $available = $firewallMod->availablePort('tcp', $port);
    $available = 1;
    unless ( $available ) {
	    $port++;
    }
  } until ( $available );

  return $port;
}


sub setPort
{
    my ($self, $port) = @_;

    # Save settings on the model
    my $uc = EBox::Global->modInstance('usercorner');
    my $settingsModel = $uc->model('Settings');
    $settingsModel->set(port => $port);
    $uc->save();
}

sub runGConf
{
  my ($self) = @_;

  my $port = $self->_availablePort();
  $self->addInternalService(
				    'name'            => 'usercorner',
				    'description'     => __('User Corner Web Server'),
				    'protocol'        => 'tcp',
				    'sourcePort'      => 'any',
				    'destinationPort' => $port,
				   );
  $self->setPort($port);
}

EBox::init();

my $uc = EBox::Global->modInstance('usercorner');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $uc,
    'version' => 1
);
$migration->execute();
