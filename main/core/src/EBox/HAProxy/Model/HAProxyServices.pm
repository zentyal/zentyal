# Copyright (C) 2014 Zentyal S.L.
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

# Class: EBox::HAProxy::Model::HAProxyServices
#
#      Form to set the reverse proxy configuration for modules
#
package EBox::HAProxy::Model::HAProxyServices;
use base 'EBox::Model::DataTable';

use EBox;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::HAProxy::View::HAProxyServicesTableCustomizer;
use EBox::Sudo;
use EBox::Types::Boolean;
use EBox::Types::Port;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;

# Constructor: new
#
#       Create the HAProxyServices model.
#
# Returns:
#
#       <EBox::HAProxy::Model::HAProxyServices> - the recently created model.
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: syncRows
#
#       Syncronizes installed modules that want to use the reverse proxy with the current model.
#
# Overrides:
#
#       <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $haproxyMod = $self->parentModule();
    my @mods = @{$haproxyMod->modsWithHAProxyService()};
    @mods = grep { not $_->HAProxyInternalService()  } @mods;

    my %currentSrvs = map {
        my $sid = $self->row($_)->valueByName('serviceId');
        $sid ? ($sid => 1) : ()
    } @{$currentRows};

    my @srvsToAdd = grep { not exists $currentSrvs{$_->_serviceId()} } @mods;

    my $modified = 0;
    for my $srv (@srvsToAdd) {
        my $enabledPort = 0;
        if (not $srv->allowServiceDisabling() and (defined $srv->defaultHTTPPort())) {
            $enabledPort = 1;
        }
        my $enabledSSLPort = 0;
        if (not $srv->allowServiceDisabling() and (defined $srv->defaultHTTPSPort())) {
            $enabledSSLPort = 1;
        }
        my $isDefaultPort = ($enabledPort and $srv->defaultHTTPPort() and (not $srv->targetVHostDomains()));
        my $isDefaultSSLPort = ($enabledSSLPort and $srv->defaultHTTPSPort() and (not $srv->targetVHostDomains()));
        my @args = ();
        push (@args, module           => $srv->name());
        push (@args, serviceId        => $srv->_serviceId());
        push (@args, service          => $srv->printableName());
        if ($enabledPort) {
            push (@args, port_selected => 'port_number');
            push (@args, port_number   => $srv->defaultHTTPPort());
        } else {
            push (@args, port_selected => 'port_disabled');
        }
        push (@args, blockPort        => $srv->blockHTTPPortChange());
        push (@args, defaultPort      => $isDefaultPort);
        if ($enabledSSLPort) {
            push (@args, sslPort_selected => 'sslPort_number');
            push (@args, sslPort_number   => $srv->defaultHTTPSPort());
        } else {
            push (@args, sslPort_selected => 'sslPort_disabled');
        }
        push (@args, blockSSLPort     => $srv->blockHTTPSPortChange());
        push (@args, defaultSSLPort   => $isDefaultSSLPort);
        push (@args, canBeDisabled    => $srv->allowServiceDisabling());

        # Warn the validators that we are doing a forced edition / addition.
        $self->{force} = 1;

        $self->addRow(@args);
        $modified = 1;
    }

    my %srvsFromModules = map { $_->_serviceId() => $_ } @mods;
    for my $id (@{$currentRows}) {
        my $row = $self->row($id);

        my $module = $row->valueByName('module');
        if (not EBox::Global->modExists($module)) {
            $self->removeRow($id);
            $modified = 1;
            next;
        }

        my $serviceId = $row->valueByName('serviceId');
        if ((not $serviceId) or (not exists $srvsFromModules{$serviceId})) {
            $self->removeRow($id);
            $modified = 1;
        }
    }

    return $modified;
}

# Method: _table
#
# Overrides:
#
#   <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
        new EBox::Types::Text(
            fieldName     => 'serviceId',
            printableName => 'serviceId',
            unique        => 1,
            hidden        => 1,
            editable      => 0,
        ),
        new EBox::Types::Text(
            fieldName     => 'module',
            printableName => 'module',
            unique        => 0,
            hidden        => 1,
            editable      => 0,
        ),
        new EBox::Types::Text(
            fieldName        => 'service',
            printableName    => __('Service'),
            unique           => 1,
            editable         => 0,
            allowUnsafeChars => 1,
        ),
        new EBox::Types::Union(
            fieldName     => 'port',
            printableName => __('HTTP port'),
            editable      => 1,
            subtypes      => [
                new EBox::Types::Union::Text(
                    fieldName     => 'port_disabled',
                    printableName => __('Disabled'),
                ),
                new EBox::Types::Port(
                    fieldName     => 'port_number',
                    printableName => __('Enabled'),
                    editable      => 1,
                    defaultValue  => 80,
                ),
            ],
        ),
        new EBox::Types::Boolean(
            fieldName     => 'defaultPort',
            printableName => __('Default for Non-SSL'),
            editable      => 1,
            help          => __('Make this service the default for the non-SSL traffic'),
        ),
        new EBox::Types::Boolean(
            fieldName     => 'blockPort',
            printableName => 'blockPort',
            hidden        => 1,
            editable      => 0,
        ),
        new EBox::Types::Union(
            fieldName     => 'sslPort',
            printableName => __('HTTPS port'),
            editable      => 1,
            subtypes      => [
                new EBox::Types::Union::Text(
                    fieldName => 'sslPort_disabled',
                    printableName => __('Disabled'),
                ),
                new EBox::Types::Port(
                    fieldName     => 'sslPort_number',
                    printableName => __('Enabled'),
                    editable      => 1,
                    defaultValue  => 443,
                ),
            ],
        ),
        new EBox::Types::Boolean(
            fieldName     => 'defaultSSLPort',
            printableName => __('Default for SSL'),
            editable      => 1,
            help          => __('Make this service the default for the SSL traffic'),
        ),
        new EBox::Types::Boolean(
            fieldName     => 'blockSSLPort',
            printableName => 'blockSSLPort',
            hidden        => 1,
            editable      => 0,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'canBeDisabled',
            printableName => 'canBeDisabled',
            hidden        => 1,
            editable      => 0,
        ),
    );

    my $dataTable = {
        tableName          => 'HAProxyServices',
        printableTableName => __('Zentyal Administration port and other reverse proxy service ports'),
        printableRowName   => __('service'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        sortedBy           => 'module',
        modelDomain        => 'HAProxy',
        help               => __('Here you may configure the services to be served from the reverse proxy'),
    };

    return $dataTable;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r, $force) = @_;

    if ($self->{force}) {
        # Either syncRows method or setServicePorts methods forced the addition / edition of this field.
        $force = delete $self->{force};
    }
    my $enabledPort = ($actual_r->{port}->selectedType() eq 'port_number');
    my $enabledSSLPort = ($actual_r->{sslPort}->selectedType() eq 'sslPort_number');
    my $port = $enabledPort ? $actual_r->{port}->value(): undef;
    my $sslPort = $enabledSSLPort ? $actual_r->{sslPort}->value() : undef;
    if ($action eq 'update') {
        if (exists $params_r->{port}) {
            if ($actual_r->{blockPort}->value()) {
                throw EBox::Exceptions::External(
                    __('This service does not allow to change the http port.')
                );
            }
        }
        if (exists $params_r->{sslPort}) {
            if ($actual_r->{blockSSLPort}->value()) {
                throw EBox::Exceptions::External(
                    __('This service does not allow to change the https port.')
                );
            }
        }
        if ((exists $params_r->{port}) and
            ($params_r->{port}->selectedType() eq 'port_disabled') and
            (exists $params_r->{sslPort}) and
            ($params_r->{sslPort}->selectedType() eq 'sslPort_disabled')) {
            if (not $actual_r->{canBeDisabled}->value()) {
                throw EBox::Exceptions::External(
                    __('This service cannot have both ports disabled.')
                );
            } else {
                $enabledPort = 0;
                $enabledSSLPort = 0;
            }
        }
        if (exists $params_r->{port}) {
            if ($params_r->{port}->selectedType() eq 'port_number') {
                $enabledPort = 1;
                $port = $params_r->{port}->value();
            } else {
                $enabledPort = 0;
            }
        }
        if (exists $params_r->{sslPort}){
            if ($params_r->{sslPort}->selectedType() eq 'sslPort_number') {
                $enabledSSLPort = 1;
                $sslPort = $params_r->{sslPort}->value();
            } else {
                $enabledSSLPort = 0;
            }
        }
    }

    if ($enabledPort and (not defined $port)) {
        throw EBox::Exceptions::External(__('The port must be defined before enable it.'));
    }
    if ($enabledSSLPort and (not defined $sslPort)) {
        throw EBox::Exceptions::External(__('The SSL port must be defined before enable it.'));
    }
    if ($enabledPort and $enabledSSLPort and ($port == $sslPort)) {
        throw EBox::Exceptions::External(__('Both SSL and non-SSL ports cannot be enabled with the same number.'));
    }

    if (($enabledPort or $enabledSSLPort) and (($action eq 'update') or ($action eq 'add'))) {
        if ($enabledPort) {
            if ($self->findValue('sslPort', $port, 1)) {
                throw EBox::Exceptions::External(__x(
                    'The port {port} is used already for SSL, you cannot use it as a non SSL port.',
                    port => $port
                ));
            }
            if ((exists $params_r->{defaultPort}) and $params_r->{defaultPort}->value and
                $self->findValueMultipleFields({ port => $port, defaultPort => 1 }, 1)) {
                throw EBox::Exceptions::External(__x(
                    'The port {port} already has a default service defined.', port => $port
                ));
            }
            unless ($force) {
                $self->checkServicePort($port);
            }
        }
        if ($enabledSSLPort) {
            if ($self->findValue('port', $sslPort, 1)) {
                throw EBox::Exceptions::External(__x(
                    'The port {port} is used already for non-SSL, you cannot use it as a SSL port.',
                    port => $sslPort
                ));
            }
            if ((exists $params_r->{defaultSSLPort}) and $params_r->{defaultSSLPort}->value and
                $self->findValueMultipleFields({ sslPort => $sslPort, defaultPort => 1 }, 1)) {
                throw EBox::Exceptions::External(__x(
                    'The port {port} already has a default service defined.', port => $sslPort
                ));
            }
            unless ($force) {
                $self->checkServicePort($sslPort);
            }

            # SSL certificate checking.
            my $moduleName = $actual_r->{module}->value();
            my $module = EBox::Global->modInstance($moduleName);
            unless ($module->pathHTTPSSSLCertificate()) {
                throw EBox::Exceptions::Internal(
                    'The module {module} cannot be used over SSL because it does not define a certificate.',
                    module => $module->name()
                );
            }
            unless (-e $module->pathHTTPSSSLCertificate()) {
                if (EBox::Global->modExists('ca')) {
                    my $ca = EBox::Global->modInstance('ca');
                    my $certificates = $ca->model('Certificates');
                    unless ($certificates->isEnabledService($module->caServiceIdForHTTPS())) {
                        my $errorMsg = __x(
                            'You need to enable the certificate for {module} on {ohref}Services Certificates{chref}',
                            service => $module->displayName(), ohref => '<a href="/CA/View/Certificates">',
                            chref => '</a>'
                        );
                        foreach my $certificate (@{$module->certificates}) {
                            if ($certificate->{serviceId} eq $module->caServiceIdForHTTPS()) {
                                my $serviceName = $certificate->{service};
                                $errorMsg = __x(
                                    'You need to enable the {serviceName} certificate for {module} on '.
                                    '{ohref}Services Certificates{chref}',
                                    serviceName => $serviceName, service => $module->displayName(),
                                    ohref => '<a href="/CA/View/Certificates">', chref => '</a>'
                                );
                                last;
                            }
                        }
                        throw EBox::Exceptions::External($errorMsg);
                    }
                } else {
                    throw EBox::Exceptions::External(__x(
                        'The SSL certificate {module} does not exists, you cannot enable SSL for this service.',
                        module => $moduleName, ohref => '<a href="/CA/View/Certificates">', chref => '</a>'
                    ));
                }
            }
        }
    }
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow) = @_;

    my $enabledPort = ($row->elementByName('port')->selectedType() eq 'port_number');
    my $port = $enabledPort ? $row->valueByName('port') : undef;
    my $oldEnabledPort = ($oldRow->elementByName('port')->selectedType() eq 'port_number');
    my $oldPort = $oldEnabledPort ? $oldRow->valueByName('port') : undef;

    my $enabledSSLPort = ($row->elementByName('sslPort')->selectedType() eq 'sslPort_number');
    my $sslPort = $enabledSSLPort ? $row->valueByName('sslPort') : undef;
    my $oldEnabledSSLPort = ($oldRow->elementByName('sslPort')->selectedType() eq 'sslPort_number');
    my $oldSSLPort = $oldEnabledSSLPort ? $oldRow->valueByName('sslPort') : undef;

    my @ports = ();
    push (@ports, $port) if ($enabledPort);
    push (@ports, $sslPort) if ($enabledSSLPort);
    my $modName = $row->valueByName('module');
    $self->parentModule()->updateServicePorts($modName, \@ports);
}

# Method: viewCustomizer
#
# Overrides:
#
#   <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::HAProxy::View::HAProxyServicesTableCustomizer();
    $customizer->setModel($self);

    return $customizer;
}

# Method: checkServicePort
#
#   Check whether a given port is being used outside HAProxy.
#
# Parameters:
#
#   port    - The port we want to check for usage.
#
sub checkServicePort
{
    my ($self, $port) = @_;

    if ($self->find(port => $port) or $self->find(sslPort => $port)) {
        # This port is being used by us so can be shared.
        return;
    }

    my $global = $self->global();
    if ($global->modExists('firewall')) {
        my $firewallMod = $global->modInstance('firewall');
        my $used = $firewallMod->portUsedByService('tcp', $port);
        if ($used) {
            throw EBox::Exceptions::External(__x(
                'Zentyal is already configured to use port {p} for {use}. Choose another port or free it and retry.',
                 p => $port,
                 use => $used
            ));
        }
    }

    my $netstatLines = EBox::Sudo::root('netstat -tlnp');
    foreach my $line (@{ $netstatLines }) {
        my ($proto, $recvQ, $sendQ, $localAddr, $foreignAddr, $state, $PIDProgram) = split '\s+', $line, 7;
        if ($localAddr =~ m/:$port$/) {
            $PIDProgram =~ s/\s*$//;
            my ($pid, $program) = split '/', $PIDProgram;
                EBox::debug("program '$program' PID $pid");
            if ($program eq 'haproxy') {
                # assumed we don't change daemon defintion to have more than one
                # daemon nor pidfile
                my $parentMod = $self->parentModule();
                my $pidFile = $parentMod->_daemons()->[0]->{pidfiles}->[0];
                my $haproxyPid = $parentMod->pidFileRunning($pidFile);
                EBox::debug("file $pidFile hapid $haproxyPid");
                if ($pid == $haproxyPid) {
                    # port used by itself
                    next;
                } else {
                    $program = __('Unmanaged instance of haproxy');
                }
            }
            throw EBox::Exceptions::External(__x(
                q{Port {p} is already in use by program '{pr}'. Choose another port or free it and retry.},
                p => $port,
                pr => $program,
            ));
        }
    }
}

# Method: setServicePorts
#
#   Sets the given ports as the ones to be used for the service module provided.
#
# Parameters:
#
#   args - Named parameters:
#       modName        - The module name that handles the service
#       port           - The port where this service should listen for connections or undef.
#       enablePort     - Whether this service's non SSL port should be enabled.
#       defaultPort    - Wehther this service's non SSL port should be the default.
#       sslPort        - The SSL port where this service should listen for connections or undef.
#       enableSSLPort  - Whether this service's SSL port should be enabled.
#       defaultSSLPort - Wehther this service's SSL port should be the default.
#       force          - Whether this service ports should be used even if are set as used elsewhere.
#
sub setServicePorts
{
    my ($self, %args) = @_;

    # Check for required arguments.
    unless ($args{modName}) {
        throw EBox::Exceptions::MissingArgument('modName');
    }
    if ($args{enablePort} and (not exists $args{port})) {
        throw EBox::Exceptions::MissingArgument('port');
    }
    if ($args{enableSSLPort} and (not exists $args{sslPort})) {
        throw EBox::Exceptions::MissingArgument('port');
    }
    if ($args{default}) {
        if (not exists $args{enablePort}) {
           throw EBox::Exceptions::MissingArgument('enablePort');
        }
        if (not exists $args{port}) {
            throw EBox::Exceptions::MissingArgument('port');
        }
    }
    if ($args{defaultSSLPort}) {
        if (not exists $args{enableSSLPort}) {
           throw EBox::Exceptions::MissingArgument('enableSSLPort');
        }
        if (not exists $args{sslPort}) {
            throw EBox::Exceptions::MissingArgument('sslPort');
        }
    }
    unless ((exists $args{port}) or (exists $args{sslPort})) {
        throw EBox::Exceptions::MissingArgument('port | sslPort');
    }

    if ($args{force}) {
        # Warn the validators that we are doing a forced edition / addition.
        $self->{force} = 1;
    }

    # Do ports validation.
    my $modName = $args{modName};
    my $port = $args{port};
    my $sslPort = $args{sslPort};
    unless ($args{force}) {
        $self->checkServicePort($port) if ($args{enablePort});
        $self->checkServicePort($sslPort) if ($args{enableSSLPort});
    }

    my $module = $self->global()->modInstance($modName);
    my $moduleRow = $self->find(serviceId => $module->_serviceId());
    if ($module->blockHTTPPortChange() and $port) {
        EBox::error("Tried to set the HTTP port of '$modName' to '$port' but it's not editable. Ignored...");
        if (defined $moduleRow) {
            my $item = $moduleRow->elementByName('port');
            if ($item->selectedType() eq 'port_number') {
                $port = $item->value();
            } else {
                $port = undef;
            }
        } else {
            $port = undef;
        }
    }
    if ($module->blockHTTPSPortChange() and $sslPort) {
        EBox::error("Tried to set the HTTPS port of '$modName' to '$sslPort' but it's not editable. Ignored...");
        if (defined $moduleRow) {
            my $item = $moduleRow->elementByName('sslPort');
            if ($item->selectedType() eq 'sslPort_number') {
                $sslPort = $item->value();
            } else {
                $sslPort = undef;
            }
        } else {
            $sslPort = undef;
        }
    }

    if (defined $moduleRow) {
        my $portItem = $moduleRow->elementByName('port');
        if ($args{enablePort}) {
            if (not $module->blockHTTPPortChange()) {
                $portItem->setValue({ port_number => $port });
            } else {
                $portItem->setValue({ port_disabled => undef });
            }
        }
        my $defaultItem = $moduleRow->elementByName('defaultPort');
        if ($args{defaultPort}) {
            $defaultItem->setValue(1);
        } else {
            $defaultItem->setValue(0);
        }
        my $sslPortItem = $moduleRow->elementByName('sslPort');
        if ($args{enableSSLPort}) {
            if (not $module->blockHTTPSPortChange()) {
                $sslPortItem->setValue({ sslPort_number => $sslPort });
            } else {
                $sslPortItem->setValue({ sslPort_disabled => undef });
            }
        }
        my $defaultSSLItem = $moduleRow->elementByName('defaultSSLPort');
        if ($args{defaultSSLPort}) {
            $defaultSSLItem->setValue(1);
        } else {
            $defaultSSLItem->setValue(0);
        }
        $moduleRow->store();
    } else {
        # There isn't yet a definition for the module Service, we add it now.
        if (not $module->blockHTTPPortChange()) {
            $port = $module->defaultHTTPPort();
        }
        if (not $module->blockHTTPSPortChange()) {
            $sslPort = $module->defaultHTTPSPort();
        }
        my @args = ();
        push (@args, module           => $module->name());
        push (@args, serviceId        => $module->_serviceId());
        push (@args, service          => $module->printableName());
        if ($args{enablePort}) {
            push (@args, port_selected => 'port_number');
            push (@args, port_number   => $port);
        } else {
            push (@args, port_selected => 'port_disabled');
        }
        push (@args, blockPort        => $module->blockHTTPPortChange());
        push (@args, defaultPort      => $args{defaultPort});
        if ($args{enableSSLPort}) {
            push (@args, sslPort_selected => 'sslPort_number');
            push (@args, sslPort_number   => $sslPort);
        } else {
            push (@args, sslPort_selected => 'sslPort_disabled');
        }
        push (@args, blockSSLPort     => $module->blockHTTPSPortChange());
        push (@args, defaultSSLPort   => $args{defaultSSLPort});
        push (@args, canBeDisabled    => $module->allowServiceDisabling());

        $self->addRow(@args);
    }

    my @ports = ();
    push (@ports, $port) if ($args{enablePort});
    push (@ports, $sslPort) if ($args{enableSSLPort});
    if (@ports) {
        $self->parentModule()->updateServicePorts($modName, \@ports);
    }
}

1;
