# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EBox::Samba::Model::DomainSettings
#
#   This model is used to configure file sharing general settings.
#
package EBox::Samba::Model::DomainSettings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Validate qw(:all);
use TryCatch;
use Encode;
use File::Slurp;

use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Boolean;
use EBox::Types::DomainName;
use EBox::Types::Text;
use EBox::Types::HostIP;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Types::Password;
use EBox::Config;
use EBox::View::Customizer;
use EBox::Exceptions::External;

use constant MAXNETBIOSLENGTH     => 15;
use constant MAXDESCRIPTIONLENGTH => 255;
use constant MODE_DC              => 'dc';
use constant MODE_ADC             => 'adc';

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

# Method: validateTypedRow
#
#   Override <EBox::Model::DataTable::validateTypedRow> method
#
sub validateTypedRow
{
    my ($self, $action, $oldParams, $newParams) = @_;

    my $netbios = exists $newParams->{'netbiosName'} ?
                         $newParams->{'netbiosName'}->value() :
                         $oldParams->{'netbiosName'}->value();

    my $workgroup = exists $newParams->{'workgroup'} ?
                           $newParams->{'workgroup'}->value() :
                           $oldParams->{'workgroup'}->value();

    my $description = exists $newParams->{'description'} ?
                             $newParams->{'description'}->value() :
                             $oldParams->{'description'}->value();

    if (uc ($netbios) eq uc ($workgroup)) {
        throw EBox::Exceptions::External(
            __('NetBIOS computer name and NetBIOS domain name must be different'));
    }
    $self->_checkNetbiosName($workgroup);
    $self->_checkDescriptionString($description);
}

sub _checkNetbiosName
{
    my ($self, $netbios) = @_;

    if (length ($netbios) <= 0) {
        throw EBox::Exceptions::External(__('NetBIOS name field is empty'));
    }
    if (length ($netbios) > MAXNETBIOSLENGTH) {
        throw EBox::Exceptions::External(__('NetBIOS name is too long'));
    }
    if ($netbios =~ m/\./) {
        throw EBox::Exceptions::External(__('NetBIOS names cannot contain dots'));
    }
}

sub _checkDescriptionString
{
    my ($self, $description) = @_;

    if (length ($description) <= 0) {
        throw EBox::Exceptions::External(__('Description string is empty'));
    }
    if (length ($description) > MAXDESCRIPTIONLENGTH) {
        throw EBox::Exceptions::External(__('Description string is too long'));
    }
}

sub _table
{
    my ($self) = @_;

    my @tableHead =
    (
        new EBox::Types::Select(
            fieldName     => 'mode',
            printableName => __('Server Role'),
            populate      => \&_server_roles,
            editable      => 1,
        ),
        new EBox::Types::DomainName(
            fieldName          => 'realm',
            printableName      => __('Realm'),
            defaultValue       => EBox::Global->modInstance('samba')->kerberosRealm(),
            editable           => 0,
        ),
        new EBox::Types::DomainName(
            fieldName     => 'dcfqdn',
            printableName => __('Domain controller FQDN'),
            editable      => 1,
        ),
        new EBox::Types::HostIP(
            fieldName     => 'dnsip',
            printableName => __('Domain DNS server IP'),
            editable      => 1,
        ),
        new EBox::Types::Text(
            # This is the administrator account used to join the zentyal
            # server to an existent domain
            fieldName     => 'adminAccount',
            printableName => __('Administrator account'),
            editable      => 1,
            allowUnsafeChars => 1,
        ),
        new EBox::Types::Password(
            fieldName     => 'password',
            printableName => __('Administrator password'),
            editable      => 1,
            hidden        => \&_adcProvisioned,
        ),
        new EBox::Types::DomainName(
            fieldName     => 'workgroup',
            printableName => __('NetBIOS domain name'),
            defaultValue  => EBox::Samba::defaultWorkgroup(),
            editable      => 1,
        ),
        new EBox::Types::Text(
            fieldName     => 'site',
            printableName => __('Site'),
            optional      => 1,
            editable      => 1,
        ),
        new EBox::Types::Text(
            fieldName     => 'netbiosName',
            printableName => __('NetBIOS computer name'),
            defaultValue  => EBox::Samba::defaultNetbios(),
            editable      => 0,
        ),
        new EBox::Types::Text(
            fieldName     => 'description',
            printableName => __('Server description'),
            defaultValue  => EBox::Samba::defaultDescription(),
            editable      => 1,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'roaming',
            printableName => __('Enable roaming profiles'),
            defaultValue  => 0,
            editable      => 1,
        ),
        new EBox::Types::Select(
            fieldName     => 'drive',
            printableName => __('Drive letter'),
            populate      => \&_drive_letters,
            editable      => 1,
        ),
    );

    my $dataTable =
    {
        tableName          => 'DomainSettings',
        pageTitle          => __('Domain'),
        printableTableName => __('Settings'),
        modelDomain        => 'Samba',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHead,
        confirmationDialog => { submit => \&confirmReprovision },
        help               => __('On this page you can set different general settings for Samba'),
    };

    return $dataTable;
}

sub _adcProvisioned
{
    my $users = EBox::Global->modInstance('samba');
    return ($users->dcMode() eq MODE_ADC and $users->getProvision->isProvisioned());
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    my $newMode  = $row->valueByName('mode');
    my $oldMode  = defined $oldRow ? $oldRow->valueByName('mode') : $newMode;

    my $newRealm = $row->valueByName('realm');
    my $oldRealm = defined $oldRow ? $oldRow->valueByName('realm') : $newRealm;
    my $newDomain = $row->valueByName('workgroup');

    my $oldDomain = defined $oldRow ? $oldRow->valueByName('workgroup') : $newDomain;

    if ($newMode ne $oldMode or $newRealm ne $oldRealm or $newDomain ne $oldDomain) {
        EBox::debug('Domain rename detected, clearing the provisioned flag');
        my $sambaMod = $self->parentModule();
        $sambaMod->getProvision->setProvisioned(0);
    }
}

sub confirmReprovision
{
    my ($self, $params) = @_;

    my $newRealm = $params->{realm};
    my $oldRealm = $self->value('realm');
    my $newDomain = $params->{workgroup};
    my $oldDomain = $self->value('workgroup');
    my $newMode = $params->{mode};
    my $oldMode = $self->value('mode');
    return undef if ($newRealm eq $oldRealm and $newDomain eq $oldDomain and $newMode eq $oldMode);
    if ($newMode eq 'dc') {
        return  __("Changing the domain name will cause to reprovision the samba database.\n\n" .
                   'The users and groups will be imported from Zentyal LDAP, but you will have to ' .
                   'rejoin all computers to the new domain.');
    } elsif ($newMode eq 'adc') {
        return __("Joining a domain will delete all your users and groups from Zentyal and import " .
                  "the domain ones.");
    }

    return undef;
}

# Populate the server role select
sub _server_roles
{
    my $roles = [];

    push (@{$roles}, { value => MODE_DC, printableValue => __('Domain controller')});
    push (@{$roles}, { value => MODE_ADC, printableValue => __('Additional domain controller')});

    # FIXME
    # These roles are disabled until implemented, we should also use better names
    #push (@roles, { value => 'standalone', printableValue => __('Standalone')});

    return $roles;
}

sub _drive_letters
{
    my $letters;

    foreach my $letter ('H'..'Z') {
        $letter .= ':';
        push (@{$letters}, { value => $letter, printableValue => $letter });
    }

    return $letters;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $actions = {
        mode => {
            dc => {
                hide => ['dcfqdn', 'dnsip', 'adminAccount', 'password'],
                show => ['roaming', 'drive'],
            },
            adc => {
                show => ['dcfqdn', 'dnsip', 'adminAccount', 'password'],
                hide => ['roaming', 'drive'],
            },
        },
    };

    push (@{$actions->{mode}->{dc}->{hide}}, 'site');

    if (EBox::Config::boolean('show_site_box')) {
        push (@{$actions->{mode}->{adc}->{show}}, 'site');
    } else {
        push (@{$actions->{mode}->{adc}->{hide}}, 'site');
    }

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setOnChangeActions($actions);
    $customizer->setInitHTMLStateOrder(['mode']);

    return $customizer;
}

1;
