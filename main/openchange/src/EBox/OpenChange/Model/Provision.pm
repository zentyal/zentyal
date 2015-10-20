# Copyright (C) 2013-2015 Zentyal S. L.
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
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::MailUserLdap;
use EBox::Types::MultiStateAction;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Password;
use EBox::Config;

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

    $self->{openchangeMod} = $self->global()->modInstance('openchange');

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
            storer        => sub {},
            volatile      => 1,
            editable      => 0)
        );
    } else {
        push (@tableDesc,  new EBox::Types::Text(
                    fieldName     => 'organizationname',
                    printableName => __('Organization name'),
                    defaultValue  => $self->_defaultOrganizationName(),
                    editable      => 1
                   ));
        push (@tableDesc, new EBox::Types::Boolean(
            fieldName     => 'enableUsers',
            printableName => __('Enable OpenChange account for all existing users'),
            defaultValue  => 0,
            editable      => 1)
         );
    # TODO: Disabled because we need some extra migration work to be done to promote an OpenChange server as the primary server.
#        push (@tableDesc, new EBox::Types::Boolean(
#            fieldName => 'registerAsMain',
#            printableName => __('Set this server as the primary server'),
#            defaultValue => 0,
#            editable      => 1)
#        );

        my $samba = $self->global()->modInstance('samba');
        if ($samba->dcMode() eq 'adc') {
            push (@tableDesc, new EBox::Types::Text(
                fieldName     => 'admin',
                printableName => __('Administrator user'),
                editable     => 1,
                help => __('Domain user belonging to the Schema Admins group'),
               ));
            push (@tableDesc, new EBox::Types::Password(
                fieldName     => 'adminPassword',
                printableName => __('Password'),
                editable      => 1,
                help => __('Password of the administrator user')
               ));
        }
    }

    my $customActions = [
        new EBox::Types::MultiStateAction(
            acquirer => \&_acquireProvisioned,
            model => $self,
            states => {
                provisioned => {
                    name => 'deprovision',
                    printableValue => __('Unconfigure'),
                    handler => \&_doDeprovision,
                    message => __('Database unconfigured'),
                    image => '/data/images/reload-plus.png',
                    enabled => sub { $self->parentModule->isProvisioned() },
                },
                notProvisioned => {
                    name => 'provision',
                    printableValue => __('Setup'),
                    handler => \&_doProvision,
                    message => __('Database configured'),
                    image => '/data/images/reload-plus.png',
                    enabled => sub { not $self->parentModule->isProvisioned() },
                },
            }
        ),
    ];

    my $dataForm = {
        tableName          => 'Provision',
        printableTableName => __('Setup'),
        pageTitle          => __('OpenChange Server Provision'),
        modelDomain        => 'OpenChange',
        customActions      => $customActions,
        tableDescription   => \@tableDesc,
        help               => __('Provision the OpenChange Groupware server. '.
                                 'This will extend and initialize the '.
                                 'required values in the LDAP schema.'),
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

    my $users = $self->global->modInstance('samba');
    unless ($users->configured()) {
        $self->{preconditionFail} = 'notConfigured';
        return undef;
    }

    unless ($users->isProvisioned()) {
        $self->{preconditionFail} = 'notProvisioned';
        return undef;
    }

    unless ($self->parentModule->isEnabled()) {
        $self->{preconditionFail} = 'notEnabled';
        return undef;
    }

    my $ca = $self->global()->modInstance('ca');
    my $availableCA = $ca->isAvailable();
    # Check there are not unsaved changes and CA is availabe
    if ($self->global->unsaved()) {
        if (not $self->parentModule->isProvisioned()) {
            if ($availableCA) {
                $self->{preconditionFail} = 'unsavedChanges';
            } else {
                $self->{preconditionFail} = 'unsavedChangesAndNoCA';
            }
            return undef;
        }
    } elsif (not $availableCA) {
        $self->{preconditionFail} = 'noCA';
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
        my $users = EBox::Global->modInstance('samba');
        return __x('You must enable the {x} module in the module ' .
                  'status section before provisioning {y} module database.',
                  x => $users->printableName(),
                  y => $self->parentModule->printableName());
    }
    if ($self->{preconditionFail} eq 'notProvisioned') {
        my $users = $self->global->modInstance('samba');
        return __x('You must provision the {x} module database before ' .
                  'provisioning the {y} module database.',
                  x => $users->printableName(),
                  y => $self->parentModule->printableName());
    }
    if ($self->{preconditionFail} eq 'notEnabled') {
        return __x('You must enable the {x} module to be able to provision its ' .
                   'database', x => $self->parentModule->printableName());
    }
    if ($self->{preconditionFail} eq 'vdomainNotFound') {
        my $users = $self->global->modInstance('samba');
        return __x('The virtual domain {x} is not defined. You can add ' .
                   'it in the {ohref}Virtual Domains page{chref}.',
                   x => $users->getProvision->getADDomain('localhost'),
                   ohref => "<a href='/Mail/View/VDomains'>",
                   chref => '</a>');
    }
    if ($self->{preconditionFail} eq 'noCA') {
        return __x('There is not an available Certication Authority. You must {oh}create or renew it{ch}',
                   oh => "<a href='/CA/Index'>",
                   ch => "</a>"
                  );
    }
    if ($self->{preconditionFail} eq 'unsavedChanges') {
        return __x('There are unsaved changes. Please save them be able to '.
                   'provision the OpenChange database.');
    }
    if ($self->{preconditionFail} eq 'unsavedChangesAndNoCA') {
        my $msg = __x('{op}There are unsaved changes. Please save them to be able to '.
                   'provision the OpenChange database.{cp}',
                      op => '<p>',
                      cp => '</p>'
                     );
        $msg .= __x('{op}There is not an available Certication Authority. You must {oh}create or renew it{ch}{cp}',
                    oh => "<a href='/CA/Index'>",
                    ch => "</a>",
                    op => '<p>',
                    cp => '</p>'
                   );
        return $msg;
    }
}

sub organizations
{
    my ($self) = @_;
    if (not exists $self->{_organizations}) {
        $self->{_organizations} = $self->{openchangeMod}->organizations();
    }

    return $self->{_organizations};
}

sub _defaultOrganizationName
{
    my ($self) = @_;

    my $default = 'First Organization';

    foreach my $organization (@{$self->organizations()}) {
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
    foreach my $organization (@{$self->organizations()}) {
        push (@existingOrganizations, {value => $organization->name(), printableValue => $organization->name()});
    }
    return \@existingOrganizations;
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

    my $organizationName         = delete $params{organizationname};
    $params{orgName} = $organizationName;

    my $openchange = $self->parentModule();
    my $state = $openchange->get_state();
    $state->{provision} = \%params;
    $openchange->set_state($state);
    $openchange->setAsChanged(1);

    my $global = $self->global();
    $global->addModuleToPostSave('samba');
    $global->addModuleToPostSave('mail');
    $global->addModuleToPostSave('webadmin');
}

sub checkForProvision
{
    my ($self, $organizationName, %params) = @_;
    my $admin         = $params{admin};
    my $adminPassword = $params{adminPassword};

    my $vdomains = $self->global()->modInstance('mail')->model('VDomains');
    my ($vdomainId) = @{ $vdomains->ids() };
    $self->_checkFirstVDomainId($vdomainId);

    my $cmd = "openchange_provision --check --firstorg='$organizationName' ";
    my $samba = $self->global()->modInstance('samba');
    my $adc = $samba->dcMode() eq 'adc';
    if ($adc) {
        if (not $admin and not $adminPassword) {
            throw EBox::Exceptions::External(__("Missing user and/or password for provision"));
        }
        $cmd .= " --user='$admin' --password='$adminPassword'";
    }

    try {
        EBox::Sudo::root($cmd);
    } catch ($ex) {
        my $errMsg;
        my $exError;
        if ($ex->isa('EBox::Exceptions::Command')) {
            $exError = join("\n", @{ $ex->error()});
        } else {
            $exError  = "$ex";
        }

        if ($exError =~ m/There is already, at least, one provisioned organization/) {
            if ($adc) {
                $errMsg = __('The PDC server either has been already provisioned or has Exchange Server installed');
            } else {
                $errMsg = __('The PDC server has been already provisioned');
            }
        } else {
            $errMsg = __x('Server cannot be provisioned: {err}', err => $exError);
        }


        throw EBox::Exceptions::External($errMsg);
    }
}

sub _checkFirstVDomainId
{
    my ($self, $vdomainId) = @_;
    if (not $vdomainId) {
        throw EBox::Exceptions::External(
            __x('To provision OpenChange you need first to {oh}create a mail virtual domain{oc}',
                oh => q{<a href='/Mail/View/VDomains'>},
                oc => q{</a>}
               )
           );
    }
}

# Method: provision
#
#   Real implementation for _doProvision that can be called also from wizard provision
#
# Parameters:
#
#   organizationName - name of the organization
#   enableUsers - *optional* enable OpenChange account for existing users
#   action - *optional* only useful when called from _doProvision
#
sub provision
{
    my ($self, $organizationName, $action, %params) = @_;
    my $enableUsers   = $params{enableUsers};
    my $admin         = $params{admin};
    my $adminPassword = $params{adminPassword};

    my $global     = $self->global();
    my $openchange = $global->modInstance('openchange');

#    my $registerAsMain = $params{registerAsMain};
    my $additionalInstallation = 0;

    unless ($organizationName) {
        throw EBox::Exceptions::DataMissing(data => __('Organization Name'));
    }

    my $vdomains = $self->global()->modInstance('mail')->model('VDomains');
    my ($vdomainId) = @{ $vdomains->ids() };
    $self->_checkFirstVDomainId($vdomainId);

    my $ca = $self->global()->modInstance('ca');
    my $state = $openchange->get_state();
    if ((not $ca->isAvailable()) and exists $state->{provision_from_wizard}) {
        my %args = %{$state->{provision_from_wizard}};
        my $commonName = "$organizationName Authority Certificate";
        $ca->createCA(commonName => $commonName, %args);

        my $vdomainToEnable = $vdomains->row($vdomainId)->valueByName('vdomain');
        $self->parentModule()->model('VDomains')->enableAllVDomain($vdomainToEnable);
    }

    foreach my $organization (@{$self->organizations()}) {
        if ($organization->name() eq $organizationName) {
            # The selected organization already exists.
            $additionalInstallation = 1;
        }
    }

    try {
        my $cmd = "openchange_provision --firstorg='$organizationName' ";

        if ($additionalInstallation) {
            $cmd .= ' --additional ';
#            if ($registerAsMain) {
#                $cmd .= ' --primary-server ';
#            }
        } else {
            $cmd .= ' --standalone ';
        }

        my $samba = $self->global()->modInstance('samba');
        if ($samba->dcMode() eq 'adc') {
            if (not $admin and not $adminPassword) {
                throw EBox::Exceptions::Internal("Missing user and/or password for provision");
            }
            $cmd .= " --user='$admin' --password='$adminPassword'";
        }

        # since this a critical one-time operation we
        # bypass configkeys cache to minimize human errors
        EBox::Config::flushConfigkeys();
        if (EBox::Config::boolean('provision_ignore_already_exists')) {
            $cmd .= '  --ignore-already-exists';
        }

        my $output = EBox::Sudo::root($cmd);
        $output = join('', @{$output});

        my $openchangeConnectionString = $self->{openchangeMod}->connectionString();

        $cmd = "openchange_provision --openchangedb " .
               "--openchangedb-uri='$openchangeConnectionString' ".
               "--firstorg='$organizationName'";
        my $output2 = EBox::Sudo::root($cmd);
        $output .= "\n" . join('', @{$output2});

        $self->_storeOrganizationNameInState($organizationName);
        $self->parentModule->setProvisioned(1);
        # Force a form definition reload to load the new provisioned content.
        $self->reloadTable();
        EBox::info("Openchange provisioned:\n$output");
        $self->setMessage($action->message(), 'note') if ($action);
    } catch ($error) {
        $self->parentModule->setProvisioned(0);
        if ($error =~ m/Failed to bind - LDAP error 49 LDAP_INVALID_CREDENTIALS/) {
            throw EBox::Exceptions::External(__('Invalid administrator user name or password'));
        }
        throw EBox::Exceptions::External(__x("Error provisioning: {error}",
                                             error => $error )
                                        );
    }

    my $defaultNC = $openchange->ldap->dn();
    my $orgDN = "CN=$organizationName,CN=Microsoft Exchange,CN=Services,CN=Configuration,$defaultNC";
    $openchange->waitForLDAPObject($orgDN);

    if ($enableUsers) {
        my $mailUserLdap = new EBox::MailUserLdap();
        my $usersModule = $self->global->modInstance('samba');
        my $adDomain = $usersModule->getProvision->getADDomain('localhost');
        my $users = $usersModule->users();
        foreach my $ldbUser (@{$users}) {
            try {
                next if ($ldbUser->isCritical());

                # Skip users with already defined mailbox
                my $samAccountName = $ldbUser->get('samAccountName');
                my $mail = $ldbUser->get('mail');
                my $mailbox = $ldbUser->get('mailbox');
                unless (defined $mailbox and length $mailbox) {
                    EBox::info("Creating user '$samAccountName' mailbox");
                    # Call API to create mailbox in zentyal
                    $mailUserLdap->setUserAccount($ldbUser,
                                                  $ldbUser->get('samAccountName'),
                                                  $adDomain);
                }

                # Skip already enabled users
                my $ac = $ldbUser->get('msExchUserAccountControl');
                unless (defined $ac and $ac == 0) {
                    my $cmd = 'openchange_newuser ';
                    $cmd .= " --create " if (not defined $ac);
                    $cmd .= " --enable '$samAccountName' ";
                    $cmd .= " --mail '$mail' ";
                    my $output = EBox::Sudo::root($cmd);
                    $output = join('', @{$output});
                    EBox::info("Enabling user '$samAccountName':\n$output");
                }
            } catch ($error) {
                EBox::error("Error enabling user " . $ldbUser->name() . ": $error");
                # Try next user
            }
        }

        # now enable groups
        my $groups = $usersModule->groups();
        foreach my $group (@{$groups}) {
            try {
                next if $group->isCritical();

                my $mail = $group->get('mail');
                next if not $mail;

                # Skip already enabled users
                my $exchangeDN = $group->get('legacyExchangeDN');
                if ($exchangeDN) {
                    next;
                }

                my $samAccountName = $group->get('samAccountName');
                my $cmd = "openchange_group --create '$samAccountName'";
                my $output = EBox::Sudo::root($cmd);
                $output = join('', @{$output});
                EBox::info("Enabling group '$samAccountName':\n$output");
            } catch ($error) {
                EBox::error("Error enabling group " . $group->name() . ": $error");
                # We will try next group
            }
        }
    }
}

sub _doDeprovision
{
    my ($self, $action, $id, %params) = @_;

    my $organizationName = $params{provisionedorganizationname};

    try {
        $self->_deprovisionUsers();

        my $cmd = 'openchange_provision --deprovision ' .
                  "--firstorg='$organizationName' ";
        my $output = EBox::Sudo::root($cmd);
        $output = join('', @{$output});

        $self->parentModule->dropSOGODB();
        $self->parentModule->setProvisioned(0);

        $self->global->modChange('mail');
        $self->global->modChange('samba');
        $self->global->modChange('openchange');

        $self->reloadTable();
        EBox::info("Openchange deprovisioned:\n$output");
        $self->setMessage($action->message(), 'note');
    } catch (EBox::Exceptions::Sudo::Command $e) {
        EBox::warn("Openchange cannot be deprovisioned:\n" . join ('\n', @{ $e->error() }));
        $self->setMessage("Openchange cannot be deprovisioned:<br />" . join ('<br />', @{ $e->error() }), 'error');
    } catch ($error) {
        throw EBox::Exceptions::External("Error deprovisioninig: $error");
        $self->parentModule->setProvisioned(1);
    }
}

sub _deprovisionUsers
{
    my ($self) = @_;
    my $usersModule = $self->global->modInstance('samba');
    my $users = $usersModule->users();
    foreach my $user (@{$users}) {
        if (not defined $user->get('msExchUserAccountControl')) {
            next;
        }

        my $username = $user->name();
        $user->delete('mailNickname', 1);
        $user->delete('homeMDB', 1);
        $user->delete('homeMTA', 1);
        $user->delete('legacyExchangeDN', 1);
        $user->delete('proxyAddresses', 1);
        $user->delete('msExchUserAccountControl', 1);
        $user->save();
    }
}

sub customActionClickedJS
{
    my ($self, $action, $id, $page) = @_;
    # provision/deprovision

    my $customActionClickedJS = $self->SUPER::customActionClickedJS($action, $id, $page);
    my $confirmationMsg;
    my $savingChangesTitle;
    my $title;
    my $wantProvision;
    my $jsStr;
    if ($action eq 'provision') {
        $title = __('Provision OpenChange');
        $confirmationMsg = __('Provisioning OpenChange will trigger the commit of unsaved configuration changes');
        $savingChangesTitle = __('Saving changes after provision');
        $jsStr = <<JS;
             console.log('onclick');
             var precheck_error = false;
             var provision_params = {};
             provision_params['orgName'] = \$('#Provision_organizationname').val();
             provision_params['admin'] = \$('#Provision_admin').val();
             provision_params['adminPassword'] = \$('#Provision_adminPassword').val();
             \$.ajax('/OpenChange/CheckForProvision', {
                   data: provision_params,
                   dataType: 'json',
                   async: false,
                   success: function(response) {
                      console.log('chekc for provision success: ' + response.success);
                      if (!response.success) {
                          Zentyal.TableHelper.setError('Provision', response.error);
                          precheck_error = true;
                      }
                   },
                   error: function(jqXHR) {
                        Zentyal.TableHelper.setError('Provision', jqXHR.responseText);
                        precheck_error = false;
                   }
              });
              if (precheck_error) {
                   console.log('precheck_error=true');
                   return false;
              }
                   console.log('precheck_error=false');

             var dialogParams = {
                  title: '$title',
                  message: '$confirmationMsg'
             };
             var acceptMethod = function() {
                  $customActionClickedJS;
                   Zentyal.Dialog.showURL('/SaveChanges?save=1', { title: '$savingChangesTitle',
                                                                   dialogClass: 'no-close',
                                                                   closeOnEscape: false
                                                                  });
             };

            Zentyal.TableHelper.showConfirmationDialog(dialogParams, acceptMethod);
            return false;
JS
    } elsif ($action eq 'deprovision') {
        $title = __('Deprovision OpenChange');
        $confirmationMsg = __('Deprovisioning OpenChange will trigger the commit of unsaved configuration changes');
        $savingChangesTitle = __('Saving changes after deprovision');
        $wantProvision = 0;
        $jsStr = <<JS;
            var dialogParams = {
                   title: '$title',
                   message: '$confirmationMsg'
            };
            var acceptMethod = function() {
                  var wantProvision    = $wantProvision;
                  $customActionClickedJS;
                   Zentyal.Dialog.showURL('/SaveChanges?save=1', { title: '$savingChangesTitle',
                                                                       dialogClass: 'no-close',
                                                                       closeOnEscape: false
                                                                      });
                   \$.getJSON('/OpenChange/IsProvisioned',  function(response) {
                       var provisionStateOk = (response.provisioned == wantProvision);
                       if (provisionStateOk) {
                          Zentyal.Dialog.showURL('/SaveChanges?save=1', { title: '$savingChangesTitle',
                                                                       dialogClass: 'no-close',
                                                                       closeOnEscape: false
                                                                      });
                        }
                  });
              };

             Zentyal.TableHelper.showConfirmationDialog(dialogParams, acceptMethod);
             return false;
JS
    }

    return $jsStr;
}



1;
