# Copyright (C) 2009-2013 Zentyal S.L.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
use strict;
use warnings;

# Class: EBox::Users::Model::Password
#
#   Class for change password model in user corner
#

package EBox::Users::Model::Password;

use base 'EBox::Model::DataForm';

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Users::Types::Password;
use EBox::Validate qw(:all);

use Encode;
use File::Temp qw/tempfile/;

use constant SAMBA_LDAPI => "ldapi://%2fvar%2flib%2fsamba%2fprivate%2fldapi" ;

sub precondition
{
    my ($self) = @_;

    my $usercornerMod = EBox::Global->modInstance('usercorner');
    unless (defined $usercornerMod) {
        $self->{preconditionFail} = 'notUserCorner';
        return undef;
    }

    unless ($usercornerMod->editableMode()) {
        $self->{preconditionFail} = 'nonEditableMode';
        return undef;
    }

    return 1;
}

sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconditionFail} eq 'notUserCorner') {
        return __('This form is only available from the User Corner application.');
    }
    if ($self->{preconditionFail} eq 'nonEditableMode') {
        return __('Password change is only available in master or standalone servers. You need to change your password from the user corner of your master server.');
    }
}

sub pageTitle
{
    return __('Password management');
}

sub _table
{
    my @tableHead =
    (
        new EBox::Users::Types::Password(
            'fieldName' => 'pass1',
            'printableName' => __('New password'),
            'size' => '8',
            'unique' => 1,
            'editable' => 1
        ),
        new EBox::Users::Types::Password(
            'fieldName' => 'pass2',
            'printableName' => __('Re-type new password'),
            'size' => '8',
            'unique' => 1,
            'editable' => 1
        ),
    );
    my $dataTable =
    {
        'tableName' => 'Password',
        'printableTableName' => __('Password'),
        'modelDomain' => 'Users',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => '', # FIXME
    };

    return $dataTable;
}

sub userCorner
{
    return 1;
}

# Method: _updateSambaPassword
#
#   Here we changed the user password in the samba database if it is
#   installed. We cannot use the EBox::Samba::User class because it
#   connects to samba LDAP using the privileged LDAP socket, and user
#   corner must not connect using it for security reasons.
#
sub _updateSambaPassword
{
    my ($self, $user, $currentPassword, $newPassword) = @_;

    if (EBox::Global->modExists('samba')) {
        my $samba = EBox::Global->modInstance('samba');
        if ($samba->configured()) {
            my $oldPass = encode('UTF16-LE', "\"$currentPassword\"");
            my $newPass = encode('UTF16-LE', "\"$newPassword\"");

            # Connect to LDAP and retrieve the base DN
            my $ldap = new Net::LDAP(SAMBA_LDAPI);
            my $rootDSE = $ldap->root_dse(attrs => ['defaultNamingContext']);
            my $defaultNC = $rootDSE->get_value('defaultNamingContext');
            my $dnsDomain = join('.', grep(/.+/, split(/[,]?DC=/, $defaultNC)));

            # Bind to perform searches
            my $bind = $ldap->bind("$user\@$dnsDomain", password => $currentPassword);
            if ($bind->is_error()) {
                my $errorMessage = $bind->error_desc();
                throw EBox::Exceptions::External(__x('Could not bind to LDAP: {x}',
                    x => $errorMessage));
            }

            # Get the user DN
            my $mesg = $ldap->search(base => $defaultNC,
                                     scope => 'sub',
                                     attrs => ['dn'],
                                     filter => "(samaccountname=$user)");
            if ($mesg->is_error()) {
                my $errorMessage = $mesg->error_desc();
                throw EBox::Exceptions::External(__x('Could not get the user DN: {x}',
                    x => $errorMessage));
            }

            # Check we only got one entry
            if ($mesg->count() != 1) {
                throw EBox::Exceptions::External(__x('The search for user {x} returned {count} results, expected one',
                    x => $user, count => $mesg->count()));
            }

            # Get the entry and the DN
            my $entry = $mesg->entry(0);
            my $sambaUserDN = $entry->dn();

            # Change the password in the samba database in first place, this
            # way if the operation fails due to password policy restrictions,
            # we don't end with different passwords between openldap and samba
            $mesg = $ldap->modify($sambaUserDN, changes => [ delete => [ unicodePwd => $oldPass ],
                    add => [ unicodePwd => $newPass ]]);
            if ($mesg->is_error) {
                my $errorMessage = $mesg->error_desc();
                throw EBox::Exceptions::External(__x('Could not change password: {x}',
                    x => $errorMessage));
            }

            # Finally unbind
            $ldap->unbind();
        }
    }
}

sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $pass1 = $paramsRef->{'pass1'};
    my $pass2 = $paramsRef->{'pass2'};

    if ($pass1->cmp($pass2) != 0) {
        throw EBox::Exceptions::External(__('Passwords do not match.'));
    }

    my $global = $self->global();
    # We don't need to check for usercorner because this form does it on its precondition check.
    my $usercornerMod = $global->modInstance('usercorner');
    my ($user, $pass, $userDN) = $usercornerMod->userCredentials();

    # Check we can instance the zentyal user
    my $zentyalUser = new EBox::Users::User(uid => $user);
    unless ($zentyalUser->exists()) {
        throw EBox::Exceptions::External(__x('User {x} not found in LDAP database'),
            x => $user);
    }

    my $newPasswd = $pass1->value();
    # Set the new password in the samba database in first place
    $self->_updateSambaPassword($user, $pass, $newPasswd);

    # At this point, the password has been changed in samba
    $zentyalUser->changePassword($newPasswd);

    $usercornerMod->updateSessionPassword($newPasswd);

    $self->setMessage(__('Password successfully updated'));
}

1;
