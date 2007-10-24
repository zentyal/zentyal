#!/usr/bin/perl

# Copyright (C) 2007  Warp Networks S.L.
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


#	Migration between gconf data version 1 to 2
#
#	In first migration from 0 to 1, a bug is made missing to
#	convert from "active" key to "enabled" key which is managed by
#	<EBox::Common::Model::EnableForm> model
#
package EBox::Migration;

use strict;
use warnings;

use base 'EBox::MigrationBase';

use EBox;
use EBox::Global;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);

# Dependencies
use Perl6::Junction qw(any);

use constant DEFAULT_DISABLED => 0;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: runGConf
#
# Overrides:
#
#     <EBox::MigrationBase::runGConf>
#
sub runGConf
{
    my $self = shift;
    my $dns = $self->{'gconfmodule'};

    my ($active, $enabled);
    if ( any(@{$dns->all_entries_base('')}) eq 'active' ) {
        $active = $dns->get_bool('active');
    } else {
        $active = undef;
    }
    if ( any(@{$dns->all_dirs_base('')}) eq 'enableForm' ) {
        $enabled = $dns->get_bool('enableForm/enabled');
    } else {
        $enabled = undef;
    }

    if ( defined ( $active ) and not defined ( $enabled )) {
        $dns->set_bool('enableForm/enabled', $active);
        $dns->set_int('enableForm/version', 0);
        $dns->set_bool('enableForm/readOnly', 0);
    } elsif ( not defined ( $active ) and not defined ( $enabled )) {
        $dns->set_bool('enableForm/enabled', DEFAULT_DISABLED);
        $dns->set_int('enableForm/version', 0);
        $dns->set_bool('enableForm/readOnly', 0);
    }
    $dns->unset('active');

}


EBox::init();
my $dns = EBox::Global->modInstance('dns');
my $migration = new EBox::Migration(
    'gconfmodule' => $dns,
    'version' => 2
);
$migration->execute();
