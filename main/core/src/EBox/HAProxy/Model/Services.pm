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

# Class: EBox::HAProxy::Model::Services
#
#      Form to set the reverse proxy configuration for modules
#
package EBox::HAProxy::Model::Services;
use base 'EBox::Model::DataTable';

use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;
use EBox::HAProxy::View::ServicesTableCustomizer;
use EBox::Types::Boolean;
use EBox::Types::Port;
use EBox::Types::Text;

# Constructor: new
#
#       Create the Services model.
#
# Returns:
#
#       <EBox::HAProxy::Model::Services> - the recently created model.
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

    my %currentSrvs = map {
        my $sid = $self->row($_)->valueByName('serviceId');
        $sid ? ($sid => 1) : ()
    } @{$currentRows};

    my @srvsToAdd = grep { not exists $currentSrvs{$_->HAProxyServiceId()} } @mods;

    my $modified = 0;
    my $enabled = 0;
    for my $srv (@srvsToAdd) {
        $enabled = $srv->allowDisableHAProxyService() ? 0 : 1;
        $self->add(
            module        => $srv->name(),
            serviceId     => $srv->HAProxyServiceId(),
            service       => $srv->printableName(),
            port          => $srv->defaultHAProxyPort(),
            blockPort     => $srv->blockHAProxyPort(),
            sslPort       => $srv->defaultHAProxySSLPort(),
            blockSSLPort  => $srv->blockHAProxySSLPort(),
            canBeDisabled => $srv->allowDisableHAProxyService(),
            enable        => $enabled);
        $modified = 1;
    }

    my %srvsFromModules = map { $_->HAProxyServiceId() => $_ } @mods;
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

# Method: disableService
#
#   Disables given service in the model.
#
sub disableService
{
    my ($self, $serviceId) = @_;

    my $row = $self->find(serviceId => $serviceId);
    if ($row) {
        $row->elementByName('enable')->setValue(0);
        $row->store();
    }
}

# Method: isEnabledService
#
#   Whether a given service is enabled in the model or not.
#
# Returns:
#
#   boolean - True if the service is enabled, undef otherwise
#
sub isEnabledService
{
    my ($self, $serviceId) = @_;

    my $row = $self->find(serviceId=> $serviceId);
    return $row->valueByName('enable') if ($row);
    return undef;
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
            printableName => __('Module'),
            unique        => 0,
            editable      => 0,
            filter => sub {
                my ($self)  = @_;
                my $modName = $self->value();
                my $mod = EBox::Global->modInstance($modName);
                # return modname if the module was uninstalled
                return $modName unless defined ($mod);
                return $mod->title();
            },
        ),
        new EBox::Types::Text(
            fieldName     => 'service',
            printableName => __('Service'),
            unique        => 1,
            editable      => 0,
            allowUnsafeChars => 1,
        ),
        new EBox::Types::Port(
            fieldName     => 'port',
            printableName => __('HTTP port'),
            editable      => 1,
            optional      => 1,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'blockPort',
            printableName => 'blockPort',
            hidden        => 1,
            editable      => 0,
        ),
        new EBox::Types::Port(
            fieldName     => 'sslPort',
            printableName => __('HTTPS port'),
            editable      => 1,
            optional      => 1,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'blockSSLPort',
            printableName => 'blockSSLPort',
            hidden        => 1,
            editable      => 0,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'enable',
            printableName => __('Enable'),
            editable      => 1,
            help          => __('Make this service accesible form the reverse proxy'),
        ),
        new EBox::Types::Boolean(
            fieldName     => 'canBeDisabled',
            printableName => 'canBeDisabled',
            hidden        => 1,
            editable      => 0,
        ),
    );

    my $dataTable = {
        tableName          => 'Services',
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
    my ($self, $action, $params_r, $actual_r) = @_;

    my $enabled = $actual_r->{enable}->value();
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
        if (exists $params_r->{enable}) {
            if (not $actual_r->{canBeDisabled}->value()) {
                throw EBox::Exceptions::External(
                    __('This service cannot be disabled.')
                );
            } else {
                $enabled = $params_r->{enable};
            }
        }
    }

    my $haproxyMod = $self->parentModule();
    my $haproxyPorts = $haproxyMod->ports();
    if ($enabled and (($action eq 'update') or ($action eq 'add'))) {
        if (exists $params_r->{port}) {
            if (exists $haproxyPorts->{$params_r->{port}}) {
                if ($haproxyPorts->{$params_r->{port}}->{isSSL}) {
                    throw EBox::Exceptions::External(__x(
                        'The port {port} is used already for SSL, you cannot use it as a non SSL port.',
                        port => $params_r->{port}
                    ));
                }
            } else {
                $haproxyMod->checkServicePort($params_r->{port});
            }
        }
        if (exists $params_r->{sslPort}) {
            if (exists $haproxyPorts->{$params_r->{sslPort}}) {
                if (not $haproxyPorts->{$params_r->{sslPort}}->{isSSL}) {
                    throw EBox::Exceptions::External(__x(
                        'The port {port} is used already for non SSL, you cannot use it as a SSL port.',
                        port => $params_r->{sslPort}
                    ));
                }
            } else {
                $haproxyMod->checkServicePort($params_r->{sslPort});
            }
        }
    }
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    my $enabled = $row->valueByName('enable');
    unless ($enabled) {
        # The row is not enabled, we can ignore it.
        return;
    }

    my $oldPort = $oldRow->valueByName('port');
    my $port = $row->valueByName('port');
    my $oldSSLPort = $oldRow->valueByName('sslPort');
    my $sslPort = $row->valueByName('sslPort');
    if (($oldPort eq $port) and ($oldSSLPort eq $sslPort)) {
        # no need to do anything
        return;
    }

    my @ports = ();
    push (@ports, $port) if ($port);
    push (@ports, $sslPort) if ($sslPort);
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

    my $customizer = new EBox::HAProxy::View::ServicesTableCustomizer();
    $customizer->setModel($self);

    return $customizer;
}

1;
