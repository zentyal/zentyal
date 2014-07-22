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

package EBox::Samba::CGI::EditGroup;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Samba;
use EBox::Samba::User;
use EBox::Samba::Group;
use EBox::Validate;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Edit group'),
                                  'template' => '/samba/editgroup.mas',
                                  @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $global   = EBox::Global->getInstance();
    my $usersMod = $global->modInstance('samba');

    my @args = ();

    $self->_requireParam('dn', 'dn');

    my $dn          = $self->unsafeParam('dn');
    my $group       = new EBox::Samba::Group(dn => $dn);
    my $grpusers    = $group->users();
    my $remainusers = $group->usersNotIn();
    my $components  = $usersMod->allGroupAddOns($group);

    my $editable = $usersMod->editableMode();

    push(@args, 'group' => $group);
    push(@args, 'groupusers' => $grpusers);
    push(@args, 'remainusers' => $remainusers);
    push(@args, 'components' => $components);
    push(@args, 'slave' => not $editable);

    $self->{params} = \@args;

    if ($self->param('edit')) {
        $self->{json} = { success => 0 };
        $self->_requireParamAllowEmpty('description', __('Description'));
        $self->_requireParamAllowEmpty('mail', __('E-Mail'));
        $self->_requireParam('type', __('type'));

        my $type = $self->param('type');
        my $isSecurityGroup = ($type eq 'security') ? 1 : 0;
        if ($isSecurityGroup != $group->isSecurityGroup()) {
            $group->setSecurityGroup($isSecurityGroup, 1);
        }

        my $description = $self->unsafeParam('description');
        if (length ($description)) {
            $group->set('description', $description, 1);
        } else {
            $group->delete('description', 1);
        }
        my $mail = $self->unsafeParam('mail');
        if ($mail) {
            if ($mail ne $group->get('mail')) {
                $group->checkMail($mail);
                $group->set('mail', $mail, 1);
            }
        } else {
            $group->delete('mail', 1);
        }
        $group->save();

        $self->{json}->{success}  = 1;
        $self->{json}->{type} = $isSecurityGroup ? 'group' : 'dgroup';
        $self->{json}->{msg} = __('Group updated');
    } elsif ($self->param('addusertogroup')) {
        $self->{json} = { success => 0 };
        $self->_requireParam('adduser', __('user'));
        my @users = $self->unsafeParam('adduser');
        foreach my $uid (@users) {
            $group->addMember(EBox::Samba::User->new(samAccountName => $uid));
        }
        $self->{json}->{success}  = 1;
    } elsif ($self->param('deluserfromgroup')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('deluser', __('user'));
        my @users = $self->unsafeParam('deluser');
        foreach my $us (@users) {
            $group->removeMember(new EBox::Samba::User(samAccountName => $us));
        }
        $self->{json}->{success}  = 1;
    } elsif ($self->param('userInfo')) {
        $self->{json} = {
             success => 1,
             member =>   [ map { $_->name } @{ $grpusers }],
             noMember => [ map { $_->name } @{ $remainusers }],
             groupEmpty => @{ $grpusers } == 0,
             usersWithMail => $self->_usersWithMail($grpusers),
             groupDN => $dn,
           };
    }
}

sub _usersWithMail
{
    my ($self, $users) = @_;
    my $mail =  EBox::Global->modInstance('mail');
    if ((not $mail) or (not $mail->configured())) {
        return 0;
    }

    my $mailUser = $mail->mailUser();
    foreach my $user (@{ $users }) {
        if ($mailUser->userAccount($user)) {
            return 1;
        }
    }

    return 0;
}

1;
