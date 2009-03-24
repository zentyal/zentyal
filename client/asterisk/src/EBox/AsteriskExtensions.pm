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


# Class: EBox::AsteriskExtensions
#
#

package EBox::AsteriskExtensions;

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Ldap;
use EBox::UsersAndGroups;
use EBox::Asterisk;

# FIXME this fixed range
use constant MINEXTN             => 1000;
use constant MAXEXTN             => 7999;
use constant EXTENSIONSDN        => 'ou=Extensions';
use constant VOICEMAILDIR        => '/var/spool/asterisk/voicemail/default/';

sub new
{
    my $class = shift;
    my $self  = {};
    $self->{ldap} = EBox::Ldap->instance();
    $self->{asterisk} = EBox::Global->modInstance('asterisk');
    bless($self, $class);
    return $self;
}


# Method: extensionsDn
#
#       Returns the dn where the extensions are stored in the ldap directory
#
# Returns:
#
#       string - dn
#
sub extensionsDn
{
    my ($self) = @_;
    return EXTENSIONSDN . "," . $self->{ldap}->dn;
}


# Method: extensions
#
#  This method returns all defined extensions
#
# Returns:
#
#     array - with all extensions names
#
sub extensions
{
    my ($self) = @_;

    my %args = (
                base => $self->extensionsDn,
                filter => 'objectclass=AsteriskExtension',
                scope => 'sub',
               );

    my $result = $self->{ldap}->search(\%args);

    my @extns = map { $_->get_value('cn')} $result->sorted('cn');

    return @extns;
}


# Method: firstFreeExtension
#
#  This method returns the first free extension
#
# Returns:
#
#     integer - extension
#     FIXME detect if we ran out of free extensions
#
sub firstFreeExtension
{
    my ($self) = @_;

    my %args = (
                base => $self->extensionsDn,
                filter => 'objectclass=AsteriskExtension',
                scope => 'sub',
                attrs => ['AstExtension']
               );

    my $result = $self->{ldap}->search(\%args);

    my @extns = map { $_->get_value('cn')} $result->sorted('cn');

    my $len = @extns;

    if ($len == 0) {
        return MINEXTN;
    } elsif ($len == 1) {
        return $extns[0]+1;
    } else {
        for (my $i=0; $i < $len-1; $i++) {
            if ($extns[$i+1]-$extns[$i]() > 1) {
                return $extns[$i]+1;
            }
        }
    }
    return $extns[$#extns]+1;
}


# Method: extensionExists
#
#       Checks if a given extension exists
#
# Parameters:
#
#       extn - extension
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub extensionExists
{
    my ($self, $extn) = @_;

    my %attrs = (
                 base => $self->extensionsDn,
                 filter => "&(objectclass=*)(AstExtension=$extn)",
                 scope => 'one'
                );

    my $result = $self->{'ldap'}->search(\%attrs);

    return ($result->count > 0);
}


# Method: addUserExtension
#
sub addUserExtension
{
    my ($self, $user, $extn) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    $self->addExtension($extn, '1', 'Dial', "SIP/$user");
    $self->addExtension($extn, '2', 'Voicemail', "$extn,u");
}


# Method: getUserExtension
#
# Returns:
#
#      integer - the CallerID should be the user's extension
#      FIXME but i don't like it :-/
#
sub getUserExtension
{
    my ($self, $user) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    my $users = EBox::Global->modInstance('users');

    my %attrs = (
                 base => $users->usersDn,
                 filter => "&(objectclass=*)(uid=$user)",
                 scope => 'one'
                );

    my $result = $self->{'ldap'}->search(\%attrs);
    my $entry = $result->entry(0);

    return ($entry->get_value('AstAccountCallerID'));
}


# Method: delUserExtension
#
sub delUserExtension
{
    my ($self, $user) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    my $extn = $self->getUserExtension($user);

    my %attrs = (
                 base => $self->extensionsDn,
                 filter => "&(objectclass=*)(AstExtension=$extn)",
                 scope => 'one'
                );

    my $result = $self->{'ldap'}->search(\%attrs);

    my @extns = map { $_->get_value('cn')} $result->sorted('cn');

    foreach (@extns) {
        $self->delExtension($_);
    }
}


# Method: modifyUserExtension
#
sub modifyUserExtension
{
    my ($self, $user, $newextn) = @_;

    if ($self->extensionExists($newextn)) {
        throw EBox::Exceptions::DataExists('data' => __('Extension'),
                                           'value' => $newextn);
    }

    my $oldextn = $self->getUserExtension($user);

    $self->delUserExtension($user);
    $self->_moveMailBox($oldextn, $newextn);
    $self->addUserExtension($user, $newextn);
}


# Method: addExtension
#
sub addExtension
{
    my ($self, $extn, $prio, $app, $data) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    my $ldap = $self->{ldap};

    my $dn = "cn=$extn-$prio," . $self->extensionsDn;

    my %attrs = (
                 attr => [
                         objectClass => 'applicationProcess',
                         objectClass => 'AsteriskExtension',
                         AstContext => 'default',
                         AstExtension => $extn,
                         AstPriority => $prio,
                         AstApplication => $app,
                         AstApplicationData => $data,
                        ],
                 
                );

    $self->{'ldap'}->add($dn, \%attrs);
}


# Method: delExtension
#
sub delExtension
{
    my ($self, $cn) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    my $ldap = $self->{ldap};

    my $dn = "cn=$cn," . $self->extensionsDn;

    $ldap->delete($dn);
}


# Method: _moveVoicemail
#
# FIXME check if .txt files need to be updated
#
sub _moveVoicemail
{
    my ($self, $old, $new) = @_;

    my $oldir = VOICEMAILDIR . $old;
    my $newdir = VOICEMAILDIR . $new;
    EBox::Sudo::root("mv $oldir $newdir");
}

1;
