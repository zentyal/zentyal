# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::CGI::Asterisk::AsteriskUserOptions;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::AsteriskLdapUser;
use EBox::Asterisk::Extensions;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Asterisk', @_);
    $self->{domain} = "ebox-asterisk";
    bless($self, $class);
    return $self;
}


sub _process($) {
    my $self = shift;
    my $astldap = new EBox::AsteriskLdapUser;
    my $extensions = new EBox::Asterisk::Extensions;

    $self->_requireParam('username', __('username'));
    my $username = $self->param('username');
    $self->{redirect} = "UsersAndGroups/User?username=$username";
    $self->keepParam('username');

    if ($self->param('active') eq 'yes') {
        $astldap->setHasAccount($username, 1);
        my $myextn = $extensions->getUserExtension($username);
        my $newextn = $self->param('extension');
        if ($newextn eq '') { $newextn = $myextn; }
        if ($newextn ne $myextn) {
            $extensions->modifyUserExtension($username, $newextn);
        }
    } else {
            $astldap->setHasAccount($username, 0);
    }
}

1;
