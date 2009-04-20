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


# Class: EBox::Asterisk::Extensions
#
#

package EBox::Asterisk::Extensions;

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Ldap;
use EBox::UsersAndGroups;
use EBox::Asterisk;

# FIXME this fixed range
use constant MINEXTN             => 1000;
use constant MAXEXTN             => 7999;
use constant VMDFTLEXTN          => 8000;
use constant MEETINGMINEXTN      => 8001;
use constant MEETINGMAXEXTN      => 8999;
use constant EXTENSIONSDN        => 'ou=Extensions';
use constant VOICEMAILDIR        => '/var/spool/asterisk/voicemail/default/';

# Constructor: new
#
#      Create the new Asterisk extensions helper
#
# Returns:
#
#      <EBox::Asterisk::Extensions> - the recently created model
#
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
#      Returns the dn where the extensions are stored in the LDAP directory
#
# Returns:
#
#      string - dn
#
sub extensionsDn
{
    my ($self) = @_;
    return EXTENSIONSDN . "," . $self->{ldap}->dn;
}


# Method: extensions
#
#      This method returns all defined extensions
#
# Returns:
#
#      array - with all extensions names
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

    my @extns = map { $_->get_value('cn') } $result->sorted('cn');

    return @extns;
}


# Method: firstFreeExtension
#
#      This method returns the first free extension or 0 if we
#      ran out of extensions.
#
# Returns:
#
#      integer - extension
#
sub firstFreeExtension
{
    my ($self) = @_;

    my %args = (
                base => $self->extensionsDn,
                filter => 'objectclass=AsteriskExtension',
                scope => 'sub',
               );

    my $result = $self->{ldap}->search(\%args);

    my @extns = map { $_->get_value('cn') } $result->sorted('cn');

    my $len = @extns;

    my $extn;
    if ($len == 0) { # this is needed in case the array is empty
        return MINEXTN;
    } elsif (($extns[0] ne MINEXTN."-1")) { # if first range value is free we return
        # it, this assures next code allways fill in the full range
        return MINEXTN;
    } else {
        for (my $i=0; $i < $len-1; $i++) {
            if ($extns[$i+1]-$extns[$i] > 1) {
                $extn = $extns[$i]+1;
                return $extn <= MAXEXTN ? $extn : 0;
            }
        }
    } # we didn't find any hole
    $extn = $extns[$#extns]+1;
    return $extn <= MAXEXTN ? $extn : 0;
}


# Method: extensionExists
#
#      Checks if a given extension exists
#
# Parameters:
#
#      extn - extension
#
# Returns:
#
#      boolean - true if it exists, otherwise false
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
# FIXME doc
sub addUserExtension
{
    my ($self, $user, $extn) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    $self->addExtension($user, '1', 'Goto', "$extn,1");
    $self->addExtension($extn, '1', 'Dial', "SIP/$user,15");
    $self->addExtension($extn, '2', 'Voicemail', "$extn,u");
    $self->addExtension($extn, '3', 'HangUp', 0);
    $self->addExtension($extn, '102', 'Voicemail', "$extn,b");
    $self->addExtension($extn, '103', 'HangUp', 0);
}


# Method: getUserExtension
#
# Returns:
#
#      integer - the CallerID should be the user's extension
#                FIXME but i don't like it :-/
#
# FIXME doc
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
# FIXME doc
sub delUserExtension
{
    my ($self, $user) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    my $extn = $self->getUserExtension($user);

    return unless $extn; # if user doesn't have an extension we are done

    my %attrs = (
                 base => $self->extensionsDn,
                 filter => "&(objectclass=*)(AstExtension=$extn)",
                 scope => 'one'
                );

    my $result = $self->{'ldap'}->search(\%attrs);

    my @extns = map { $_->get_value('cn') } $result->sorted('cn');


    foreach (@extns) {
        $self->delExtension($_);
    }

    $self->delExtension("$user-1"); #FIXME not so cool
}


# Method: modifyUserExtension
#
# FIXME doc
sub modifyUserExtension
{
    my ($self, $user, $newextn) = @_;

    if ($self->extensionExists($newextn)) {
        throw EBox::Exceptions::DataExists('data' => __('Extension'),
                                           'value' => $newextn);
    }

    my $oldextn = $self->getUserExtension($user);

    if ($oldextn) { # user already had an extension
        $self->delUserExtension($user);
        $self->_moveVoicemail($oldextn, $newextn);
    }
    $self->addUserExtension($user, $newextn);

    my $ldap = EBox::Ldap->instance();
    my $users = EBox::Global->modInstance('users');

    my $dn = "uid=" . $user . "," . $users->usersDn;

    if ($oldextn) { # user already had an extension
        my %attrs = (
            'AstAccountCallerID' => $newextn, #FIXME if add fullname here this wont work
            'AstAccountMailbox'  => $newextn  #FIXME random?
        );
        $ldap->modify($dn, { replace => \%attrs });
    } else { # we give a new $newextn extension
        my %attrs = (
            'AstAccountCallerID'   => $newextn, #FIXME if add fullname here this wont work
            'AstAccountMailbox'    => $newextn, #FIXME random?
            'AstAccountVMPassword' => $newextn
        );
        $ldap->modify($dn, { replace => \%attrs });
    }
}


# Method: addExtension
#
# FIXME doc
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
# FIXME doc
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
sub _moveVoicemail
{
    my ($self, $old, $new) = @_;

    my $olddir = VOICEMAILDIR . $old;
    my $newdir = VOICEMAILDIR . $new;
    if (-d $olddir) {
        EBox::Sudo::root("mv $olddir $newdir");
    }
}


# Method: cleanUpMeetings
#
# FIXME doc
sub cleanUpMeetings
{
    my ($self) = @_;

    my %args = (
                base => $self->extensionsDn,
                filter => '(&(objectclass=AsteriskExtension)(AstApplication=MeetMe))',
                scope => 'sub',
               );

    my $result = $self->{ldap}->search(\%args);

    my @extns = map { {
                          cn => $_->get_value('cn'),
                          extn => $_->get_value('AstExtension'),
                    } } $result->sorted('cn');

    foreach my $extn (@extns) {
        if (($self->MEETINGMINEXTN < $extn->{'extn'}) and ($extn->{'extn'} < $self->MEETINGMAXEXTN)) {
            $self->delExtension($extn->{'cn'});
        }
    }
}

# Method: checkExtension
#
#      Check the validity for a given extension
#
# Parameters:
#
#      extension - extension to check
#      name      - data's name to be used when throwing an Exception
#      begin     - (optional) begin of the range of valid extensions
#      end       - (optional) end of the range of valid extensions
#
# Returns:
#
#      boolean - True if the extension is correct
#                False on failure when parameter name is NOT defined
#
# Exceptions:
#
#      If name is passed an exception will be raised on failure
#
#      <EBox::Exceptions::InvalidData> - extension is incorrect
#
sub checkExtension
{
    my ($self, $extension, $name, $begin, $end) = @_;

    unless($extension =~/^\d+$/){
        if ($name) {
            throw EBox::Exceptions::InvalidData
                  ('data' => $name, 'value' => $extension);
        } else {
            return undef;
        }
    }

    if (defined($begin) and defined($end)) {
        if (($begin <= $extension) and ($extension <= $end)) {
            return 1;
        } else {
            if ($name) {
                throw EBox::Exceptions::InvalidData
                      ('data' => $name, 'value' => $extension);
            } else {
                return undef;
            }
        }
    } else {
        return 1;
    }
}

1;
