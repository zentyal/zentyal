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

#  Migration between gconf data version
#
#  This is intended to add mailfilter account to domains created with previous
#  verisons of mailfilter
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Sudo;

sub runGConf
{
  my ($self) = @_;

  # if module is not configured we will add the clamav user to the group p3scan
  # in the module configuration stage
  my $mailfilter = $self->{gconfmodule};
  return if not $mailfilter->configured();


  EBox::Sudo::root('addgroup clamav p3scan');
}

EBox::init();
my $mailfilter = EBox::Global->modInstance('mailfilter');
my $migration = new EBox::Migration(
                                     'gconfmodule' => $mailfilter,
                                     'version' => 3,
                                    );
$migration->execute();


1;
