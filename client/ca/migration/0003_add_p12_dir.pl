#!/usr/bin/perl

# Copyright (C) 2010 eBox Technologies S.L.
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

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::CA;

use base 'EBox::Migration::Base';

use constant PRIVATEDIRMODE => 00700;

# Constructor: new
#
#      Overrides at <EBox::Migration::Base::new> method
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
#       <EBox::Migration::Base::runGConf>
#
sub runGConf
{
    my $self = shift;

    mkdir(EBox::CA::P12DIR, PRIVATEDIRMODE) unless (-d EBox::CA::P12DIR);

}

EBox::init();
my $ca = EBox::Global->modInstance('ca');
my $migration = new EBox::Migration(
				     'gconfmodule' => $ca,
				     'version' => 3
				    );
$migration->execute();
