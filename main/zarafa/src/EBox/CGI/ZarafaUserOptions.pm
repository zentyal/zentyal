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

package EBox::CGI::Zarafa::ZarafaUserOptions;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::ZarafaLdapUser;

## arguments:
##	title [required]
sub new
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Zarafa',
				      @_);
	$self->{domain} = 'ebox-zarafa';

	bless($self, $class);
	return $self;
}

sub _process
{
	my ($self) = @_;

	my $zarafaldap = new EBox::ZarafaLdapUser;

	$self->_requireParam('username', __('username'));
	my $username = $self->param('username');
	$self->{redirect} = "UsersAndGroups/User?username=$username";

	$self->keepParam('username');

    if ($self->param('active') eq 'yes') {
        $zarafaldap->setHasAccount($username, 1);
        if (defined($self->param('is_admin'))) {
            $zarafaldap->setIsAdmin($username, 1);
        } else {
            $zarafaldap->setIsAdmin($username, 0);
        }
    } else {
        if (defined($self->param('contact'))) {
            $zarafaldap->setHasContact($username, 1);
        } else {
            $zarafaldap->setHasContact($username, 0);
        }
        $zarafaldap->setHasAccount($username, 0);
    }
}

1;
