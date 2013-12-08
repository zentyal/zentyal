# Copyright (C) 2006-2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

package EBox::Sudo::TestStub;
# Description:
#
use strict;
use warnings;

use EBox::Sudo;
use File::Temp qw(tempfile);
# XXX there are unclear situation with comamnds containig ';' but this is also de case of EBox::Sudo


use Readonly;
Readonly::Scalar our $GOOD_SUDO_PATH => $EBox::Sudo::SUDO_PATH;
Readonly::Scalar our $FAKE_SUDO_PATH => '';

Readonly::Scalar our $GOOD_STDERR_FILE => $EBox::Sudo::STDERR_FILE;

my ($fh,$tmpfile) = tempfile();
close $fh;

Readonly::Scalar  our $FAKE_STDERR_FILE => $tmpfile;



sub fake
{
  *EBox::Sudo::SUDO_PATH = \$FAKE_SUDO_PATH;
  *EBox::Sudo::STDERR_FILE = \$FAKE_STDERR_FILE;
}


sub unfake
{
   *EBox::Sudo::SUDO_PATH = \$GOOD_SUDO_PATH;
   *EBox::Sudo::STDERR_FILE = \$GOOD_STDERR_FILE;
}

sub isFaked
{
  return $EBox::Sudo::SUDO_PATH ne $GOOD_SUDO_PATH;
}


1;
