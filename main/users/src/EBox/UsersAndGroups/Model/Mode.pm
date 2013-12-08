# Copyright (C) 2009-2012 Zentyal S.L.
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

# Class: EBox::UsersAndGroups::Model::Mode
#
# This class contains the options needed to enable the usersandgroups module.

package EBox::UsersAndGroups::Model::Mode;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::KrbRealm;
use EBox::Exceptions::InvalidData;

use strict;
use warnings;

# Group: Public methods

# Constructor: new
#
#      Create a data form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless( $self, $class );

    return $self;
}

# Method: validateTypedRow
#
#   Check the kerberos realm and LDAP base DN
#
# Overrides:
#
#   <EBox::Model::DataForm::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;

    if (exists $changedFields->{dn}) {
        my $dn = $changedFields->{dn}->value();
        $self->_validateDN($dn);
    }
}

# Method: _table
#
#	Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{
    my ($self) = @_;

    my @tableDesc = (
        new EBox::Types::Text (
            fieldName => 'dn',
            printableName => __('LDAP DN'),
            editable => 1,
            allowUnsafeChars => 1,
            size => 36,
            defaultValue => $self->_dnFromHostname(),
            help => __('This will be the DN suffix in LDAP tree')
        ),
    );

    my $dataForm = {
        tableName           => 'Mode',
        printableTableName  => __('Configuration'),
        pageTitle           => __('Zentyal Users'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Users',
    };

    return $dataForm;
}

sub getDnFromDomainName
{
    my ($self, $domainName) = @_;

    my $dn = $domainName;
    $dn =~ s/[^A-Za-z0-9\.]/-/g;
    $dn = join (',', map ("dc=$_", split (/\./, $dn)));
    return $dn;
}

sub _dnFromHostname
{
    my ($self) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $domain = $sysinfo->hostDomain();
    return $self->getDnFromDomainName($domain);
}

# TODO: Move this to EBox::Validate or even create a new DN type
sub _validateDN
{
    my ($self, $dn) = @_;

    unless ($dn =~ /^dc=[^,=]+(,dc=[^,=]+)*$/) {
        throw EBox::Exceptions::InvalidData(data => __('LDAP DN'), value => $dn);
    }
}

1;
