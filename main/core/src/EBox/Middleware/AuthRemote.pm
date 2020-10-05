# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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
use strict;
use warnings;

package EBox::Middleware::AuthRemote;
use base qw(EBox::Middleware::Auth);

use File::Slurp;

sub checkValidUser
{
    my ($self, $uuid) = @_;

    my $uuid_file = '/var/lib/zentyal/.uuid';

    if (-f $uuid_file) {
        my $file_content = read_file($uuid_file);
        chomp($file_content);

        if ($uuid eq $file_content) {
            return 1;
        } else {
            return 0;
        }
    }
}

1;
