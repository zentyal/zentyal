# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Asterisk::CGI::AsteriskGroupOptions;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::AsteriskLdapUser;
use EBox::Asterisk::Extensions;
use EBox::Users::Group;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Asterisk', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json}->{success} = 0;

    my $astldap = new EBox::AsteriskLdapUser;
    my $extensions = new EBox::Asterisk::Extensions;

    $self->_requireParam('group', __('group'));
    my $group = $self->unsafeParam('group');


    $group = new EBox::Users::Group(dn => $group);

    if ($astldap->asteriskUsersInQueue($group) == 0) {
        throw EBox::Exceptions::External(__('There are no users in this group or the users do not have an Asterisk account, so a queue cannot be created.'));
    }

    if ($self->param('active') eq 'yes') {
        $astldap->setHasQueue($group, 1);
        $self->{json}->{enabled} = 1;

        my $myextn = $extensions->getQueueExtension($group);
        $self->{json}->{extension} = $myextn;

        my $newextn = $self->param('extension');
        if ($newextn and ($newextn ne $myextn)) {
            $extensions->modifyQueueExtension($group, $newextn);
            $self->{json}->{extension} = $newextn;
        }

        $self->{json}->{msg} = __x('Asterisk group queue enabled with extension {ext}', ext => $newextn ? $newextn : $myextn);
    } else {
        $astldap->setHasQueue($group, 0);
        $self->{json}->{enabled} = 0;
        $self->{json}->{msg} = __('Asterisk group queue disabled');
    }
    $self->{json}->{success} = 1;
}

1;
