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

# XXX remove when this block is included in EBox::Migration::Base


sub fwRuleForInternalService
{
  my ($self, $service, $target) = @_;
  $service or
    throw EBox::Exceptions::MissingArgument('service');
  $target or
    $target = 'accept';

  my $fw = EBox::Global->modInstance('firewall');
  $fw->setInternalService($service, $target);
  $fw->saveConfigRecursive();
}


# XXX END OF BLOCK


sub runGConf
{
  my ($self) = @_;

  my $serviceMod = EBox::Global->modInstance('services');

  if (not $serviceMod->serviceExists('name' => 'dns')) {
      $serviceMod->addMultipleService(
                                name => 'dns',
                                description => 'Domain Name Service',
                                services => [
                                             {
                                              'protocol' => 'udp',
                                              'sourcePort' => 'any',
                                              'destinationPort' => 53,
                                             },
                                             {
                                              'protocol' => 'tcp',
                                              'sourcePort' => 'any',
                                              'destinationPort' => 53,
                                             },
                                            ],

                               );
      $serviceMod->saveConfig();

  } else {
      EBox::info("Not adding DNS service as it already exists");      
  }


  $self->fwRuleForInternalService('dns');
}

EBox::init();

my $dnsMod = EBox::Global->modInstance('dns');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $dnsMod,
    'version' => 1
);
$migration->execute();
