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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Class: EBox::UsersAndGroups::Model::Mode
#
# This class contains the options needed to enable the usersandgroups module.

use strict;
use warnings;

package EBox::UsersAndGroups::Model::Mode;
use base 'EBox::Model::DataForm';

use EBox::UsersAndGroups;

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::DomainName;
use EBox::Types::Password;

use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::View::Customizer;

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless( $self, $class );

    return $self;
}


sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;
    if ($self->parentModule->configured()) {
        throw EBox::Exceptions::External(__('This parameters could not be changed once the user module has been configured.'));
    }

    my $mode = $allFields->{mode}->value();
    if ($mode eq EBox::UsersAndGroups->NORMAL_MODE) {
        $self->_validateNormalMode($allFields);
    } elsif ($mode eq EBox::UsersAndGroups->EXTERNAL_AD_MODE) {
        $self->_validateExternalADMode($allFields);
    } else {
        throw EBox::Exceptions::Internal("Invalid users mode: $mode");
    }
}

sub _validateNormalMode
{
    my ($self, $params) = @_;
    my $dn = $params->{dn}->value();
    if (not $dn) {
        throw EBox::Exceptions::MissingArgument($params->{dn}->printableName());
    }

    $self->_validateDN($dn);
}

sub _validateExternalADMode
{
    my ($self, $params) = @_;
    my @needed = qw(dcHostname dcUser dcPassword);
    foreach my $name (@needed) {
        my $element = $params->{$name};
        if (not $element->value()) {
            throw EBox::Exceptions::MissingArgument($element->printableName());
        }
    }

    my $user = $params->{dcUser}->value();
    if ($user =~ m/@/) {
        throw EBox::Exceptions::External(
            __('The use should not contain a domain. The domain will be extracted from Active Directory')
           );
    }
}

sub _table
{
    my ($self) = @_;

    my @tableDesc = (
        EBox::Types::Select->new(
            fieldName => 'mode',
            printableName => __('Server mode'),
            editable => 1,
            populate => \&_modeOptions,
        ),
        EBox::Types::Text->new(
            fieldName => 'dn',
            printableName => __('LDAP DN'),
            editable => 1,
            allowUnsafeChars => 1,
            size => 36,
            defaultValue => $self->_dnFromHostname(),
            help => __('This will be the DN suffix in LDAP tree'),
        ),
        EBox::Types::DomainName->new(
            fieldName => 'dcHostname',
            printableName => __('Active Directory hostname'),
            editable => 1,
            optional => 1,
        ),
        EBox::Types::Text->new(
            fieldName => 'dcUser',
            printableName => __('Administrative user of the Active Directory'),
            help          =>
               __('This user has to have enough permissions to create a computer account in the domain'),
            editable => 1,
            unsafeParam => 1,
            optional => 1,
        ),
        EBox::Types::Password->new(
            fieldName => 'dcPassword',
            printableName => __('User password'),
            editable => 1,
            unsafeParam => 1,
            optional => 1,
        )
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

sub viewCustomizer
{
    my ($self) = @_;
    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    my $normalParams = [qw/dn/];
    my $adParams = [qw/dcHostname dcUser dcPassword/];

    $customizer->setOnChangeActions({
        mode => {
                EBox::UsersAndGroups->NORMAL_MODE  => {
                    show    => $normalParams,
                    hide    => $adParams,
                },
                EBox::UsersAndGroups->EXTERNAL_AD_MODE => {
                    show  => $adParams,
                    hide => $normalParams,
                }
       }
    });
    return $customizer;
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

sub modePrintableName
{
    my ($self) = @_;
    my $modeEl = $self->row()->elementByName('mode');
    return $modeEl->printableValue();
}

sub _modeOptions
{
    return [
        {
            value => EBox::UsersAndGroups->NORMAL_MODE,
            printableValue => __('Normal'),
        },
        {
            value => EBox::UsersAndGroups->EXTERNAL_AD_MODE,
            printableValue => __('Use external Active Directory server'),
        },

       ];
}

sub adModeOptions
{
    my ($self) = @_;
    return [
        dcHostname => $self->value('dcHostname'),
        user       => $self->value('dcUser'),
        password   => $self->value('dcPassword'),
       ];
}

1;
