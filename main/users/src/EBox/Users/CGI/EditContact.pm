# Copyright (C) 2013 Zentyal S.L.
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

package EBox::Users::CGI::EditContact;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Users;
use EBox::Users::Contact;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/users/editcontact.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $usersMod = EBox::Global->modInstance('users');

    $self->{title} = __('Contacts');

    my @args = ();

    $self->_requireParam('dn', 'dn');

    my $dn = $self->unsafeParam('dn');
    my $contact = new EBox::Users::Contact(dn => $dn);

    my $contactgroups = $contact->groups();
    my $remaingroups = $contact->groupsNotIn();

    my $editable = $usersMod->editableMode();

    push(@args, 'contact' => $contact);
    push(@args, 'contactgroups' => $contactgroups);
    push(@args, 'remaingroups' => $remaingroups);
    push(@args, 'slave' => not $editable);

    $self->{params} = \@args;

    if ($self->param('edit')) {
        $self->{json} = { success => 0 };

        if ($editable) {
            $self->_requireParam('firstname', __('first name'));
            $self->_requireParam('surname', __('last name'));
            $self->_requireParamAllowEmpty('description', __('description'));
            $self->_requireParamAllowEmpty('mail', __('E-mail'));

            my $givenName = $self->param('firstname');
            my $surname = $self->param('surname');
            my $fullname = "$givenName $surname";
            if ($fullname ne $contact->get('cn')) {
                $contact->checkCN($contact->parent(), $fullname);
            }

            my $mail = $self->param('mail');

            my $description = $self->unsafeParam('description');
            if (length ($description)) {
                $contact->set('description', $description, 1);
            } else {
                $contact->delete('description', 1);
            }

            $contact->set('givenname', $givenName, 1);
            $contact->set('sn', $surname, 1);
            $contact->set('mail', $mail, 1);

            $contact->save();
            $self->{json}->{set_text} = $contact->fullname();
        }

        $self->{json}->{success} = 1;
        $self->{json}->{msg} = __('Contact updated');
    } elsif ($self->param('addgrouptocontact')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('addgroup', __('group'));
        my @groups = $self->unsafeParam('addgroup');

        foreach my $gr (@groups) {
            my $group = new EBox::Users::Group(gid => $gr);
            $contact->addGroup($group);
        }

        $self->{json}->{success} = 1;
    } elsif ($self->param('delgroupfromcontact')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('delgroup', __('group'));

        my @groups = $self->unsafeParam('delgroup');
        foreach my $gr (@groups){
            my $group = new EBox::Users::Group(gid => $gr);
            $contact->removeGroup($group);
        }

        $self->{json}->{success} = 1;
    } elsif ($self->param('groupInfo')) {
        $self->{json} = {
             success => 1,
             member =>   [ map { $_->name } @{ $contactgroups }],
             noMember => [ map { $_->name } @{ $remaingroups }],
           };
    }

}

1;
