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

package EBox::Samba::CGI::EditUser;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Samba;
use EBox::Samba::User;
use EBox::Samba::Group;
use EBox::Gettext;
use EBox::Exceptions::External;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/edituser.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    my $global = EBox::Global->getInstance();
    my $users  = $global->modInstance('samba');

    $self->{'title'} = __('Users');

    my @args = ();

    $self->_requireParam('dn', 'dn');

    my $dn = $self->unsafeParam('dn');
    my $user = new EBox::Samba::User(dn => $dn);

    my $components = $users->allUserAddOns($user);
    my $usergroups = $user->groups(internal => 0, system => 1);
    my $remaingroups = $user->groupsNotIn(internal => 0, system => 1);

    my $editable = $users->editableMode();

    push(@args, 'user' => $user);
    push(@args, 'usergroups' => $usergroups);
    push(@args, 'remaingroups' => $remaingroups);
    push(@args, 'components' => $components);

    $self->{params} = \@args;

    if ($self->param('edit')) {
        my $setText = undef;
        $self->{json} = { success => 0 };

        $self->_requireParam('User_quota_selected');
        my $quotaTypeSelected = $self->param('User_quota_selected');
        my $quota;
        if ($quotaTypeSelected eq 'quota_disabled') {
            $quota = 0;
        } elsif ($quotaTypeSelected eq 'quota_size') {
            $quota = $self->param('User_quota_size');
        }
        if (defined $quota) {
            if (not $user->hasValue('objectClass', 'systemQuotas')) {
                $user->add('objectClass', 'systemQuotas');
            }
            $user->set('quota', $quota, 1);
        }

        my ($addMail, $delMail);
        my $modDN = 0;
        if ($editable) {
            $self->_requireParam('givenname', __('first name'));
            $self->_requireParam('surname', __('last name'));
            $self->_requireParamAllowEmpty('displayname', __('display name'));
            $self->_requireParamAllowEmpty('description', __('description'));
            $self->_requireParamAllowEmpty('mail', __('E-Mail'));
            $self->_requireParamAllowEmpty('password', __('password'));
            $self->_requireParamAllowEmpty('repassword', __('confirm password'));

            my $givenName = $self->param('givenname');
            my $surname = $self->param('surname');
            my $disabled = $self->param('disabled');

            $modDN = ($givenName ne $user->givenName() or $surname ne $user->surname());
            if ($modDN) {
                my $newCN = $user->generatedFullName(givenName => $givenName,
                                                     initials  => scalar($user->initials()),
                                                     sn        => $surname);
                if ($user->fullname() ne $newCN) {
                    $user->save();  # Save any previous modified data
                    # Perform the moddn
                    $user->setFullName($newCN);
                } else {
                    $modDN = 0;
                }
            }


            my $displayname = $self->unsafeParam('displayname');
            if (length ($displayname)) {
                $user->set('displayName', $displayname, 1);
                $setText = $user->name() . " ($displayname)";
            } else {
                $user->delete('displayName', 1);
                $setText = $user->name();
            }
            my $description = $self->unsafeParam('description');
            if (length ($description)) {
                $user->set('description', $description, 1);
            } else {
                $user->delete('description', 1);
            }

            my $mail = $self->unsafeParam('mail');
            my $oldMail = $user->get('mail');
            if ($mail) {
                $mail = lc $mail;
                if (not $oldMail) {
                    $addMail = $mail;
                } elsif  ($mail ne $oldMail) {
                    $delMail = 1;
                    $addMail = $mail;
                }
            } elsif ($oldMail) {
                $delMail = 1;
            }

            my $mailMod = $global->modInstance('mail');
            if ($delMail) {
                if ($mailMod and $mailMod->configured()) {
                    $mailMod->_ldapModImplementation()->delUserAccount($user);
                } else {
                    $user->delete('mail', 1);
                }
            }
            if ($addMail) {
                if ($mailMod and $mailMod->configured()) {
                    $mailMod->_ldapModImplementation()->setUserAccount($user, $addMail);
                } else {
                    $user->checkMail($addMail);
                    $user->set('mail', $addMail, 1);
                }
            }

            $user->set('givenname', $givenName, 1) if ($givenName);
            $user->set('sn', $surname, 1) if ($surname);
            $user->setDisabled($disabled, 1);

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
        if ($addMail) {
            $self->{json}->{mail} = $addMail;
        } elsif ($delMail) {
            $self->{json}->{mail} = '';
        }
        if ($modDN) {
            $self->{json}->{reload} = 1;
        }
    } elsif ($self->param('addgrouptouser')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('addgroup', __('group'));
        my @groups = $self->unsafeParam('addgroup');

        foreach my $gr (@groups) {
            my $group = new EBox::Samba::Group(samAccountName => $gr);
            $user->addGroup($group);
        }

        $self->{json}->{success} = 1;
    } elsif ($self->param('delgroupfromuser')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('delgroup', __('group'));

        my @groups = $self->unsafeParam('delgroup');
        foreach my $gr (@groups){
            my $group = new EBox::Samba::Group(samAccountName => $gr);
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
