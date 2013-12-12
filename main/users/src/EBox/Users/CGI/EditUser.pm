# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Users::CGI::EditUser;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Users;
use EBox::Users::User;
use EBox::Gettext;
use EBox::Exceptions::External;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/users/edituser.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');

    $self->{'title'} = __('Users');

    my @args = ();

    $self->_requireParam('dn', 'dn');

    my $dn = $self->unsafeParam('dn');
    my $user = new EBox::Users::User(dn => $dn);

    my $components = $users->allUserAddOns($user);
    my $usergroups = $user->groups(internal => 0, system => 1);
    my $remaingroups = $user->groupsNotIn(internal => 0, system => 1);

    my $editable = $users->editableMode();

    push(@args, 'user' => $user);
    push(@args, 'usergroups' => $usergroups);
    push(@args, 'remaingroups' => $remaingroups);
    push(@args, 'components' => $components);
    push(@args, 'slave' => not $editable);

    $self->{params} = \@args;

    if ($self->param('edit')) {
        my $setText = 0;
        $self->{json} = { success => 0 };
        $self->_requireParamAllowEmpty('quota', __('quota'));
        $user->set('quota', $self->param('quota'), 1);

        if ($editable) {
            $self->_requireParam('givenname', __('first name'));
            $self->_requireParam('surname', __('last name'));
            $self->_requireParamAllowEmpty('description', __('description'));
            $self->_requireParamAllowEmpty('mail', __('E-Mail'));
            $self->_requireParamAllowEmpty('password', __('password'));
            $self->_requireParamAllowEmpty('repassword', __('confirm password'));

            my $givenName = $self->param('givenname');
            my $surname = $self->param('surname');
            my $disabled = $self->param('disabled');

            my $fullname = "$givenName $surname";
            if ($fullname ne $user->get('cn')) {
                $user->checkCN($user->parent(), $fullname);
                $setText = $user->get('uid') . " ($fullname)";
            }

            my $description = $self->unsafeParam('description');
            if (length ($description)) {
                $user->set('description', $description, 1);
            } else {
                $user->delete('description', 1);
            }
            my $mail = $self->unsafeParam('mail');
            if (length ($mail)) {
                $user->set('mail', $mail, 1);
            } else {
                $user->delete('mail', 1);
            }

            $user->set('givenname', $givenName, 1);
            $user->set('sn', $surname, 1);
            $user->set('cn', $fullname, 1);
            $user->setDisabled($disabled);

            # Change password if not empty
            my $password = $self->unsafeParam('password');
            if ($password) {
                my $repassword = $self->unsafeParam('repassword');
                if ($password ne $repassword){
                    throw EBox::Exceptions::External(__('Passwords do not match.'));
                }

                $user->changePassword($password, 1);
            }
        }

        $user->save();

        $self->{json}->{success} = 1;
        $self->{json}->{msg} = __('User updated');
        if ($setText) {
            $self->{json}->{set_text} = $setText;
        }
    } elsif ($self->param('addgrouptouser')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('addgroup', __('group'));
        my @groups = $self->unsafeParam('addgroup');

        foreach my $gr (@groups) {
            my $group = new EBox::Users::Group(gid => $gr);
            $user->addGroup($group);
        }

        $self->{json}->{success} = 1;
    } elsif ($self->param('delgroupfromuser')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('delgroup', __('group'));

        my @groups = $self->unsafeParam('delgroup');
        foreach my $gr (@groups){
            my $group = new EBox::Users::Group(gid => $gr);
            $user->removeGroup($group);
        }

        $self->{json}->{success} = 1;
    } elsif ($self->param('groupInfo')) {
        $self->{json} = {
             success => 1,
             member =>   [ map { $_->name } @{ $usergroups }],
             noMember => [ map { $_->name } @{ $remaingroups }],
        };
    }
}

1;
