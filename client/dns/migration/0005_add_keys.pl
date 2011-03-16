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

# This migration script set the TSIG key for all domains

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

sub runGConf
{
    my ($self) = @_;

    try {
        my $domainModel = $self->{gconfmodule}->model('DomainTable');
        foreach my $id (@{$domainModel->ids()}) {
            my $row = $domainModel->row($id);
            unless ( $row->valueByName('tsigKey') ) {
                # Create a new tsigKey if it is not there already
                my $secret = $domainModel->_generateSecret();
                $row->elementByName('tsigKey')->setValue($secret);
                $row->store();
            }
        }
    } otherwise { };

}

EBox::init();

my $dnsMod = EBox::Global->modInstance('dns');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $dnsMod,
    'version' => 5
);
$migration->execute();
