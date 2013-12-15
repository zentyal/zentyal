# Copyright (C) 2013 Zentyal S. L.
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

package EBox::OpenChange::Model::Provision;

use base 'EBox::Model::DataForm';

use EBox::DBEngineFactory;
use EBox::Gettext;
use EBox::MailUserLdap;
use EBox::Samba::User;
use EBox::Types::MultiStateAction;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::Union;

use TryCatch::Lite;

# Method: new
#
#   Constructor, instantiate new model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    $self->{global} = EBox::Global->getInstance();
    $self->{openchangeMod} = $self->{global}->modInstance('openchange');
    $self->{organizations} = $self->{openchangeMod}->organizations();

    return $self;
}

# Method: _table
#
#   Returns model description
#
sub _table
{
    my ($self) = @_;

    my @tableDesc = ();
    if ($self->parentModule->isProvisioned()) {
        push (@tableDesc, new EBox::Types::Text(
            fieldName     => 'provisionedorganizationname',
            printableName => __('Organization Name'),
            acquirer      => \&_acquireOrganizationNameFromState,
            storer        => \&_emptyFunc,
            volatile      => 1,
            editable      => 0)
        );
    } else {
        push (@tableDesc, new EBox::Types::Union(
            fieldName     => 'organizationname',
            printableName => __('Organization Name'),
            editable      => 1,
            subtypes      => [
                new EBox::Types::Text(
                    fieldName     => 'neworganizationname',
                    printableName => __('New One'),
                    defaultValue  => $self->_defaultOrganizationName(),
                    editable      => 1),
                new EBox::Types::Select(
                    fieldName     => 'existingorganizationname',
                    printableName => __('Existing One'),
                    populate      => \&_existingOrganizationNames,
                    editable      => 1),
            ])
        );
        push (@tableDesc, new EBox::Types::Boolean(
            fieldName     => 'enableUsers',
            printableName => __('Enable OpenChange account for all existing users'),
            defaultValue  => 1,
            editable      => 1)
        );
# TODO: Disabled because we need some extra migration work to be done to promote an OpenChange server as the primary server.
#        push (@tableDesc, new EBox::Types::Boolean(
#            fieldName => 'registerAsMain',
#            printableName => __('Set this server as the primary server'),
#            defaultValue => 0,
#            editable      => 1)
#        );
    }

    my $customActions = [
#        new EBox::Types::MultiStateAction(
#            acquirer => \&_acquireProvisioned,
#            model => $self,
#            states => {
#                provisioned => {
#                    name => 'deprovision',
#                    printableValue => __('Unconfigure'),
#                    handler => \&_doDeprovision,
#                    message => __('Database unconfigured'),
#                    enabled => sub { $self->parentModule->isEnabled() },
#                },
#                notProvisioned => {
#                    name => 'provision',
#                    printableValue => __('Setup'),
#                    handler => \&_doProvision,
#                    message => __('Database configured'),
#                    enabled => sub { $self->parentModule->isEnabled() },
#                },
#            }
#        ),
        new EBox::Types::Action(
            name           => 'provision',
            printableValue => __('Setup'),
            model          => $self,
            handler        => \&_doProvision,
            message        => __('Database configured'),
            enabled        => sub { not $self->parentModule->isProvisioned() },
        ),
    ];


    my $dataForm = {
        tableName          => 'Provision',
        printableTableName => __('Setup'),
        pageTitle          => __('OpenChange Server Provision'),
        modelDomain        => 'OpenChange',
        #defaultActions     => [ 'editField' ],
        customActions      => $customActions,
        tableDescription   => \@tableDesc,
        help               => __('Setup an OpenChange Groupware server.'),
    };

    return $dataForm;
}

# Method: precondition
#
#   Check samba is configured and provisioned
#
sub precondition
{
    my ($self) = @_;

    my $samba = $self->global->modInstance('samba');
    unless ($samba->configured()) {
        $self->{preconditionFail} = 'notConfigured';
        return undef;
    }
    unless ($samba->isProvisioned()) {
        $self->{preconditionFail} = 'notProvisioned';
        return undef;
    }
    unless ($self->parentModule->isEnabled()) {
        $self->{preconditionFail} = 'notEnabled';
        return undef;
    }

    # Check the samba domain is present in the Mail Virtual Domains model
    my $mailModule = $self->global->modInstance('mail');
    my $VDomainsModel = $mailModule->model('VDomains');
    my $adDomain = $samba->getProvision->getADDomain('localhost');
    my $adDomainFound = 0;
    foreach my $id (@{$VDomainsModel->ids()}) {
        my $row = $VDomainsModel->row($id);
        my $vdomain = $row->valueByName('vdomain');
        if (lc $vdomain eq lc $adDomain) {
            $adDomainFound = 1;
            last;
        }
    }
    unless ($adDomainFound) {
        $self->{preconditionFail} = 'vdomainNotFound';
        return undef;
    }

    # Check there are not unsaved changes
    if ($self->global->unsaved() and (not $self->parentModule->isProvisioned())) {
        $self->{preconditionFail} = 'unsavedChanges';
        return undef;
    }

    return 1;
}

# Method: preconditionFailMsg
#
#   Show the precondition failure message
#
sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconditionFail} eq 'notConfigured') {
        my $samba = EBox::Global->modInstance('samba');
        return __x('You must enable the {x} module in the module ' .
                  'status section before provisioning {y} module database.',
                  x => $samba->printableName(),
                  y => $self->parentModule->printableName());
    }
    if ($self->{preconditionFail} eq 'notProvisioned') {
        my $samba = $self->global->modInstance('samba');
        return __x('You must provision the {x} module database before ' .
                  'provisioning the {y} module database.',
                  x => $samba->printableName(),
                  y => $self->parentModule->printableName());
    }
    if ($self->{preconditionFail} eq 'notEnabled') {
        return __x('You must enable the {x} module before provision the ' .
                   'database', x => $self->parentModule->printableName());
    }
    if ($self->{preconditionFail} eq 'vdomainNotFound') {
        my $samba = $self->global->modInstance('samba');
        return __x('The virtual domain {x} is not defined. You can add ' .
                   'it in the {ohref}Virtual Domains page{chref}.',
                   x => $samba->getProvision->getADDomain('localhost'),
                   ohref => "<a href='/Mail/View/VDomains'>",
                   chref => '</a>');
    }
    if ($self->{preconditionFail} eq 'unsavedChanges') {
        return __x('There are unsaved changes. Please save them before '.
                   'provision');
    }
}

sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    # FIXME: This code is not working with Union type.
    my $onChange = {
        organizationname => {
            neworganizationname => {
                show => [],
                hide => ['enableUsers'],
            },
            existingorganizationname => {
                show => ['enableUsers'],
                hide => [],
            },
        },
    };
    $customizer->setOnChangeActions($onChange);
    return $customizer;
}

sub _defaultOrganizationName
{
    my ($self) = @_;

    my $default = 'First Organization';

    foreach my $organization (@{$self->{organizations}}) {
        if ($organization->name() eq $default) {
            # The default organization name is already used, return empty string
            return '';
        }
    }
    return $default;
}

sub _existingOrganizationNames
{
    my ($self) = @_;

    my @existingOrganizations = ();
    foreach my $organization (@{$self->{organizations}}) {
        push (@existingOrganizations, {value => $organization->name(), printableValue => $organization->name()});
    }
    return \@existingOrganizations;
}

sub _emptyFunc
{

}

sub _acquireProvisioned
{
    my ($self, $id) = @_;

    my $provisioned = $self->parentModule->isProvisioned();
    return ($provisioned) ? 'provisioned' : 'notProvisioned';
}

sub _acquireOrganizationNameFromState
{
    my ($type) = @_;

    my $model     = $type->model();
    my $module    = $model->parentModule();
    my $state     = $module->get_state();
    my $modelName = $model->name();
    my $keyField  = 'organizationname';
    my $value = $state->{$modelName}->{$keyField};
    if (defined($value) and ($value ne '')) {
        return $value;
    }
    return undef;
}

sub _storeOrganizationNameInState
{
    my ($self, $name) = @_;

    my $model     = $self;
    my $module    = $model->parentModule();
    my $state     = $module->get_state();
    my $modelName = $model->name();
    my $keyField  = 'organizationname';
    if ($name) {
        $state->{$modelName}->{$keyField} = $name;
    } else {
        delete $state->{$modelName}->{$keyField};
    }
    $module->set_state($state)
}

sub _doProvision
{
    my ($self, $action, $id, %params) = @_;

    my $organizationNameSelected = $params{organizationname_selected};
    my $organizationName = $params{$organizationNameSelected};
    my $enableUsers = $params{enableUsers};
#    my $registerAsMain = $params{registerAsMain};
    my $additionalInstallation = 0;

    unless ($organizationName) {
        throw EBox::Exceptions::DataMissing(data => __('Organization Name'));
    }

    foreach my $organization (@{$self->{organizations}}) {
        if ($organization->name() eq $organizationName) {
            # The selected organization already exists.
            $additionalInstallation = 1;
        }
    }

    try {
        my $cmd = '/opt/samba4/sbin/openchange_provision ' .
                  "--firstorg='$organizationName' ";

        if ($additionalInstallation) {
            $cmd .= ' --additional ';
#            if ($registerAsMain) {
#                $cmd .= ' --primary-server ';
#            }
        } else {
            $cmd .= ' --standalone ';
        }

        my $output = EBox::Sudo::root($cmd);
        $output = join('', @{$output});

        $cmd = '/opt/samba4/sbin/openchange_provision ' .
               "--openchangedb " .
               "--firstorg='$organizationName'";
        my $output2 = EBox::Sudo::root($cmd);
        $output .= "\n" . join('', @{$output2});

        $self->_storeOrganizationNameInState($organizationName);
        $self->parentModule->setProvisioned(1);
        # Force a form definition reload to load the new provisioned content.
        $self->reloadTable();
        EBox::info("Openchange provisioned:\n$output");
        $self->setMessage($action->message(), 'note');
    } catch ($error) {
        $self->parentModule->setProvisioned(0);
        throw EBox::Exceptions::External("Error provisioninig: $error");
    }
    $self->global->modChange('mail');
    $self->global->modChange('samba');
    $self->global->modChange('openchange');

    if ($enableUsers) {
        my $mailUserLdap = new EBox::MailUserLdap();
        my $sambaModule = $self->global->modInstance('samba');
        my $adDomain = $sambaModule->getProvision->getADDomain('localhost');
        my $usersModule = $self->global->modInstance('users');
        my $users = $usersModule->users();
        foreach my $ldapUser (@{$users}) {
            try {
                my $ldbUser = $sambaModule->ldbObjectFromLDAPObject($ldapUser);
                next unless $ldbUser;
                my $samAccountName = $ldbUser->get('samAccountName');

                my $critical = $ldbUser->get('isCriticalSystemObject');
                next if (defined $critical and $critical eq 'TRUE');

                # Skip users with already defined mailbox
                my $mailbox = $ldapUser->get('mailbox');
                unless (defined $mailbox and length $mailbox) {
                    EBox::info("Creating user '$samAccountName' mailbox");
                    # Call API to create mailbox in zentyal
                    $mailUserLdap->setUserAccount($ldapUser,
                                                  $ldapUser->get('uid'),
                                                  $adDomain);
                }

                # Skip already enabled users
                my $ac = $ldbUser->get('msExchUserAccountControl');
                unless (defined $ac and $ac == 0) {
                    my $cmd = "/opt/samba4/sbin/openchange_newuser ";
                    $cmd .= " --create " if (not defined $ac);
                    $cmd .= " --enable '$samAccountName' ";
                    my $output = EBox::Sudo::root($cmd);
                    $output = join('', @{$output});
                    EBox::info("Enabling user '$samAccountName':\n$output");
                }
            } catch ($error) {
                EBox::error("Error enabling user " . $ldapUser->name() . ": $error");
                # Try next user
            }
        }
    }
}

#sub _doDeprovision
#{
#    my ($self, $action, $id, %params) = @_;
#
#    my $organizationName = $params{organizationname};
#
#    try {
#        my $cmd = '/opt/samba4/sbin/openchange_provision ' .
#                  '--deprovision ' .
#                  "--firstorg='$organizationName' ";
#        my $output = EBox::Sudo::root($cmd);
#        $output = join('', @{$output});
#
#        $cmd = 'rm -rf /opt/samba4/private/openchange.ldb';
#        my $output2 = EBox::Sudo::root($cmd);
#        $output .= "\n" . join('', @{$output2});
#
#        # Drop SOGo database and db user. To avoid error if it does not exists,
#        # the user is created and granted harmless privileges before drop it
#        my $db = EBox::DBEngineFactory::DBEngine();
#        my $dbName = $self->parentModule->_sogoDbName();
#        my $dbUser = $self->parentModule->_sogoDbUser();
#        $db->sqlAsSuperuser(sql => "DROP DATABASE IF EXISTS $dbName");
#        $db->sqlAsSuperuser(sql => "GRANT USAGE ON *.* TO $dbUser");
#        $db->sqlAsSuperuser(sql => "DROP USER $dbUser");
#
#        $self->parentModule->setProvisioned(0);
#        EBox::info("Openchange deprovisioned:\n$output");
#        $self->setMessage($action->message(), 'note');
#    } catch ($error) {
#        throw EBox::Exceptions::External("Error deprovisioninig: $error");
#        $self->parentModule->setProvisioned(1);
#    }
#}

1;
