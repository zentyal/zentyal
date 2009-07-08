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

# Class: EBox::Samba::Model::PDC
#
#   This model is used to configure PDC settings.
#

package EBox::Samba::Model::PDC;

use EBox::Gettext;
use EBox::Validate qw(:all);
use Error qw(:try);
use POSIX;

use EBox::Samba;
use EBox::SambaLdapUser;
use EBox::Types::Int;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Config;

use strict;
use warnings;

use base 'EBox::Model::DataForm';


sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

# Method: precondition
#
#   Check if PDC is enabled.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $mod = $self->parentModule();
    return $mod->configured() and $mod->pdc();
}

# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail
#
sub preconditionFailMsg
{
    my ($self) = @_;

    my $mod = $self->parentModule();
    return __('File sharing module is not enabled.') unless $mod->configured();
    return __('PDC is not enabled.') unless $mod->pdc();
}

sub _table
{
    my @tableHead =
    (
        new EBox::Types::Union(
            'fieldName' => 'minPwdLength',
            'printableName' => __('Minimum password length'),
            'subtypes' => [
                new EBox::Types::Union::Text(
                    'fieldName' => 'minPwdLength_disabled',
                    'printableName' => __('Disabled'),
                ),
                new EBox::Types::Int(
                    'fieldName' => 'minPwdLength_characters',
                    'printableName' => __('Limited to'),
                    'trailingText' => __('characters'),
                    'size' => 2,
                    'defaultValue' => 5,
                    'editable' => 1,
                ),
            ],
        ),
        new EBox::Types::Union(
            'fieldName' => 'maxPwdAge',
            'printableName' => __('Maximum password age'),
            'subtypes' => [
                new EBox::Types::Union::Text(
                    'fieldName' => 'maxPwdAge_disabled',
                    'printableName' => __('Disabled'),
                ),
                new EBox::Types::Int(
                    'fieldName' => 'maxPwdAge_days',
                    'printableName' => __('Limited to'),
                    'trailingText' => __('days'),
                    'size' => 3,
                    'defaultValue' => 90,
                    'editable' => 1,
                ),
            ],
        ),
        new EBox::Types::Union(
            'fieldName' => 'pwdHistoryLength',
            'printableName' => __('Enforce password history'),
            'subtypes' => [
                new EBox::Types::Union::Text(
                    'fieldName' => 'pwdHistoryLength_disabled',
                    'printableName' => __('Disabled'),
                ),
                new EBox::Types::Int(
                    'fieldName' => 'pwdHistoryLength_keep',
                    'printableName' => __('Keep history for'),
                    'trailingText' => __('passwords remebered'),
                    'size' => 2,
                    'defaultValue' => 5,
                    'editable' => 1,
                ),
            ],
        ),
    );
    my $dataTable =
    {
        'tableName' => 'PDC',
        'printableTableName' => __('PDC'),
        'modelDomain' => 'Samba',
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => __('On this page you can set different PDC related settings'),
    };

    return $dataTable;
}

# Method: setTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::setTypedRow>
#
sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $minPwdLength = $paramsRef->{'minPwdLength'}->value();
    if ($minPwdLength eq 'minPwdLength_disabled') {
        $minPwdLength = 0;
    }
    my $maxPwdAge = $paramsRef->{'maxPwdAge'}->value();
    if ($maxPwdAge eq 'maxPwdAge_disabled') {
        $maxPwdAge = -1;
    } else {
        # Convert to seconds
        $maxPwdAge = $maxPwdAge * 24 * 60 * 60;
    }
    my $pwdHistoryLength = $paramsRef->{'pwdHistoryLength'}->value();
    if ($pwdHistoryLength eq 'pwdHistoryLength_disabled') {
        $pwdHistoryLength = 0;
    }

    my $users = EBox::Global->modInstance('users');
    my $ldap = $users->{ldap};

    my $sambaLdap = new EBox::SambaLdapUser();
    my $domain = $sambaLdap->sambaDomainName();
    my $dn = "sambaDomainName=$domain," . $ldap->dn();

    $ldap->setAttribute($dn, 'sambaMinPwdLength', $minPwdLength);
    $ldap->setAttribute($dn, 'sambaMaxPwdAge', $maxPwdAge);
    $ldap->setAttribute($dn, 'sambaPwdHistoryLength', $pwdHistoryLength);
}

# Method: row
#
#       Return the row reading data from LDAP.
#
# Overrides:
#
#       <EBox::Model::DataForm::row>
#
sub row
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    $users->uidList(); # XXX Force LDAP connection
    my $ldap = $users->{ldap};

    my $sambaLdap = new EBox::SambaLdapUser();
    my $domain = $sambaLdap->sambaDomainName();
    my $dn = "sambaDomainName=$domain," . $ldap->dn();

    my $minPwdLengthField;
    my $minPwdLength = $ldap->getAttribute($dn, 'sambaMinPwdLength');
    if ($minPwdLength == 0) {
        $minPwdLengthField = 'minPwdLength_disabled';
    } else {
        $minPwdLengthField = 'minPwdLength_characters';
    }

    my $maxPwdAgeField;
    my $maxPwdAge = $ldap->getAttribute($dn, 'sambaMaxPwdAge');
    if ($maxPwdAge == -1) {
        $maxPwdAgeField = 'maxPwdAge_disabled';
    } else {
        # Convert to days
        $maxPwdAge = floor($maxPwdAge / 24 / 60 / 60);
        $maxPwdAgeField = 'maxPwdAge_days';
    }

    my $pwdHistoryLengthField;
    my $pwdHistoryLength = $ldap->getAttribute($dn, 'sambaPwdHistoryLength');
    if ($pwdHistoryLength == 0) {
        $pwdHistoryLengthField = 'pwdHistoryLength_disabled';
    } else {
        $pwdHistoryLengthField = 'pwdHistoryLength_keep';
    }

    my $row = $self->_setValueRow(minPwdLength     => {$minPwdLengthField,
                                                       $minPwdLength},
                                  maxPwdAge        => {$maxPwdAgeField,
                                                       $maxPwdAge},
                                  pwdHistoryLength => {$pwdHistoryLengthField,
                                                       $pwdHistoryLength});
    # Dummy id for dataform
    $row->setId('dummy');
    return $row;
}

# Method: headTile
#
#   Overrides <EBox::Model::DataTable::headTitle> 
#
#
sub headTitle
{
        return undef;
}

1;
