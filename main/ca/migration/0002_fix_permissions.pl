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

use constant DIRMODE        => '0751';
use constant PRIVATEDIRMODE => '0700';

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

    my $cmd = 'chmod ' . DIRMODE . ' ' . EBox::CA::CATOPDIR;
    EBox::Sudo::root($cmd) if (-d EBox::CA::CATOPDIR);
    $cmd = 'chmod ' . DIRMODE . ' ' . EBox::CA::CERTSDIR;
    EBox::Sudo::root($cmd) if (-d EBox::CA::CERTSDIR);
    $cmd = 'chmod ' . DIRMODE . ' ' . EBox::CA::CRLDIR;
    EBox::Sudo::root($cmd) if (-d EBox::CA::CRLDIR);
    $cmd = 'chmod ' . DIRMODE . ' ' . EBox::CA::NEWCERTSDIR;
    EBox::Sudo::root($cmd) if (-d EBox::CA::NEWCERTSDIR);
    $cmd = 'chmod ' . DIRMODE . ' ' . EBox::CA::KEYSDIR;
    EBox::Sudo::root($cmd) if (-d EBox::CA::KEYSDIR);
    $cmd = 'chmod ' . DIRMODE . ' ' . EBox::CA::REQDIR;
    EBox::Sudo::root($cmd) if (-d EBox::CA::REQDIR);
    $cmd = 'chmod ' . PRIVATEDIRMODE . ' ' . EBox::CA::PRIVDIR;
    EBox::Sudo::root($cmd) if (-d EBox::CA::PRIVDIR);
}

EBox::init();
my $ca = EBox::Global->modInstance('ca');
my $migration = new EBox::Migration(
				     'gconfmodule' => $ca,
				     'version' => 2
				    );
$migration->execute();
