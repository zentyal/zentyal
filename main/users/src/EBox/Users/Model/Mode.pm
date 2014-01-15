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

# Class: EBox::Users::Model::Mode
#
# This class contains the options needed to enable the usersandgroups module.

use strict;
use warnings;

package EBox::Users::Model::Mode;
use base 'EBox::Model::DataForm';

use EBox::Users;

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::DomainName;
use EBox::Types::Password;

use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::View::Customizer;

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless( $self, $class );

    return $self;
}

# Method: updatedRowNotify
#
#   If the mode is changed, we mark the DNS module as changed to force a
#   resolvconf update, which will setup or not localhost as the unique
#   resolver depending on the selected mode
#
# Overrides:
#
#   <EBox::Model::DataForm::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    my $mode = $row->valueByName('mode');
    my $oldMode = $oldRow->valueByName('mode');
    if (not defined $oldMode or $mode ne $oldMode) {
        $self->global->modChange('dns');
    }
}

sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;
    my $mode = $allFields->{mode}->value();
    if ($mode eq EBox::Users->STANDALONE_MODE) {
        $self->_validateNormalMode($allFields);
    } elsif ($mode eq EBox::Users->EXTERNAL_AD_MODE) {
        if ($self->parentModule->configured()) {
            throw EBox::Exceptions::External(__('External AD mode cannot be set once the users module has been configured.'));
        }
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

    my $hostname =  $params->{dcHostname}->value();
    my $dcDomain;
    $dcDomain = $hostname;
    $dcDomain =~ s/^(.*?)\.//;
    my $hostDomain = $self->global()->modInstance('sysinfo')->hostDomain();
    if ($hostDomain ne $dcDomain) {
        throw EBox::Exceptions::External(
           __x('Invalid DC hostname {dc}; it must be in the same domain that the Zentyal server. Current Zentyal server domain is {dom}',
               dc => $hostname,
               dom => $hostDomain,
              )
        );
    }

    my $user = $params->{dcUser}->value();
    if ($user =~ m/@/) {
        throw EBox::Exceptions::External(
            __('The user should not contain a domain. The domain will be automatically extracted from Active Directory')
           );
    }

    if ($params->{dcPassword}->value() ne $params->{dcPassword2}->value()) {
        throw EBox::Exceptions::External(__('User password and confirm user password does not match'));
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
            help =>  __('Both the Active Directory hostname and the own Zentyal server hostname should be DNS resolvable'),
            editable => 1,
            optional => 1,
        ),
        EBox::Types::Text->new(
            fieldName => 'dcUser',
            printableName => __('Administrative user of the Active Directory'),
            help          =>
               __('This user has to have enough permissions to create a computer account in the domain'),
            editable => 1,
            allowUnsafeChars => 1,
            optional => 1,
        ),
        EBox::Types::Password->new(
            fieldName => 'dcPassword',
            printableName => __('User password'),
            editable => 1,
            allowUnsafeChars => 1,
            optional => 1,
        ),
        EBox::Types::Password->new(
            fieldName => 'dcPassword2',
            printableName => __('Confirm user password'),
            editable => 1,
            allowUnsafeChars => 1,
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
    my $standaloneParams = [qw/dn/];
    my $adParams = [qw/dcHostname dcUser dcPassword dcPassword2/];

    $customizer->setOnChangeActions({
        mode => {
                EBox::Users->STANDALONE_MODE  => {
                    show    => $standaloneParams,
                    hide    => $adParams,
                },
                EBox::Users->EXTERNAL_AD_MODE => {
                    show  => $adParams,
                    hide => $standaloneParams,
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
    my ($self, $modeValue) = @_;
    if (not $modeValue) {
        $modeValue = $self->row()->valueByName('mode');
    }
    foreach my $option (@{ _modeOptions() }) {
        if ($option->{value} eq $modeValue) {
            return $option->{printableValue};
        }
    }

    # nothing found, return mode vlaue
    return $modeValue;
}

sub _modeOptions
{
    return [
        {
            value => EBox::Users->STANDALONE_MODE,
            printableValue => __('Standalone server'),
        },
        {
            value => EBox::Users->EXTERNAL_AD_MODE,
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
