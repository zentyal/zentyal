#!/usr/bin/perl -w

# Copyright (C) 2007 Warp Networks S.L.
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
#	In version 0, no keys was stored in GConf
#
#       In version 1, a key to check if the CA is password aware is
#       created
#

package EBox::Migration;

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);

use base 'EBox::MigrationBase';

use constant DEFAULT_PASS_REQUIRED  => 0;

# Constructor: new
#
#      Overrides at <EBox::MigrationBase::new> method
#
# Returns:
#
#      A recently created <EBox::Migration> object
#
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
#       <EBox::MigrationBase::runGConf>
#
sub runGConf
{
	my $self = shift;
	my $ca = $self->{'gconfmodule'};

        $ca->set_bool('pass_required', DEFAULT_PASS_REQUIRED);

}

EBox::init();
my $ca = EBox::Global->modInstance('ca');
my $migration = new EBox::Migration(
				     'gconfmodule' => $ca,
				     'version' => 1
				    );
$migration->execute();
