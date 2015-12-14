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
use strict;
use warnings;

# Class: EBox::CA::Model::Certificates
#
#      Form to set the rollover certificates for modules
#

package EBox::CA::Model::Certificates;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Types::DomainName;
use EBox::Types::Boolean;
use EBox::CA;
use EBox::Exceptions::External;

# Group: Public methods

# Constructor: new
#
#       Create the new Certificates model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::CA::Model::Certificates> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: caAvailable
#
#   Check if CA has been created.
#
sub caAvailable
{
    my ($self) = @_;

    my $ca = EBox::Global->modInstance('ca');

    return $ca->isAvailable();
}

sub permanentMessage
{
    my ($self) = @_;
    if ($self->caAvailable()) {
        return undef;
    }

    return __x('This configuration will not be enforced until a new certification authority is created. '
              . 'Go to {openhref}Certification Authority{closehref} to do so',
              openhref  => qq{<a href='/CA/Index'>},
              closehref => qq{</a>});    
}

sub permanentMessageType
{
    return 'warning';
}
   

# Method: syncRows
#
#       Syncronizes installed modules certificate requests with the current model.
#
# Overrides:
#
#       <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my @srvs = @{EBox::CA::Certificates->srvsCerts()};
    my %currentSrvs = map {
        my $sid = $self->row($_)->valueByName('serviceId');
        $sid ?  ($sid => 1) : ()
    } @{$currentRows};

    my @srvsToAdd = grep { not exists $currentSrvs{$_->{'serviceId'}} } @srvs;

    my $modified = 0;
    for my $srv (@srvsToAdd) {
        my $cn = exists $srv->{'defaultCN'} ? $srv->{'defaultCN'} : __('Zentyal');
        my $allowCustomCN = exists $srv->{allowCustomCN} ?
                                       $srv->{allowCustomCN}  : 1;
        $self->add(module => $srv->{'module'},
                   serviceId =>  $srv->{'serviceId'},
                   service => $srv->{'service'},
                   cn => $cn,
                   allowCustomCN => $allowCustomCN,
                   enable => 0);
        $modified = 1;
    }

    my %srvsFromModules = map { $_->{serviceId} => $_ } @srvs;
    for my $id (@{$currentRows}) {
        my $row = $self->row($id);

        my $module = $row->valueByName('module');
        if (not EBox::Global->modExists($module)) {
            $self->removeRow($id);
            $modified = 1;
            next;
        }

        if ($row->valueByName('enable')) {
            # already created certificates are held
            next;
        }

        my $serviceId = $row->valueByName('serviceId');
        if ( not $serviceId or
             not exists $srvsFromModules{$serviceId}
            ) {
            $self->removeRow($id);
            $modified = 1;
        }
    }

    return $modified;
}

# Method: disableService
#
#       Disables given service in the model.
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

# Method: setServiceRO
#
#       Set service as read-only.
#
sub setServiceRO
{
    my ($self, $serviceId, $ro) = @_;

    my $row = $self->find(serviceId => $serviceId);
    if ($row) {
        $row->setReadOnly($ro);
        $row->store();
    }
}

# Method: updateCN
#
#       Updates the CN in the certificate for the given service.
#
sub updateCN
{
    my ($self, $serviceId, $cn) = @_;

    my $row = $self->find(serviceId => $serviceId);
    if ($row) {
        $row->elementByName('cn')->setValue($cn);
        $row->store();
    }
}

# Method: certUsedByService
#
#       Returns if a given certificate Common Name is used by any
#       of the services in the model.
#
# Returns:
#
#       True if the certificate is used, false otherwise
#
sub certUsedByService
{
    my ($self, $cn) = @_;

    my $row = $self->find(cn => $cn);
    return 1 if ($row);
    return 0;
}

# Method: cnByService
#
#       Returns the certificate Common Name used by a service.
#
# Returns:
#
#       The Common Name if exists, undef otherwise.
#
sub cnByService
{
    my ($self, $serviceId) = @_;

    my $row = $self->find(serviceId => $serviceId);
    return $row->valueByName('cn') if ($row);
    return undef;
}

# Method: isEnabledService
#
#       Returns if a given service is enabled in the model.
#
# Returns:
#
#       True if the service is enabled, undef otherwise
#
sub isEnabledService
{
    my ($self, $serviceId) = @_;

    my $row = $self->find(serviceId=> $serviceId);
    return $row->valueByName('enable') if ($row);
    return undef;
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader =
      (
       new EBox::Types::Text(
                                fieldName     => 'serviceId',
                                printableName =>  'serviceId',
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
       new EBox::Types::Text(
                                fieldName     => 'cn',
                                printableName => __('Common Name'),
                                unique           => 0,
                                editable         => 1,
                                allowUnsafeChars => 1,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'enable',
                                printableName => __('Enable'),
                                editable      => 1,
                                help          => __('Generate the certificate using CA '
                                                    . 'with the common name set above'),
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'allowCustomCN',
                                printableName => 'allowCustomCN',
                                editable      => 0,
                                hidden        => 1,
                                defaultValue  => 1,
                               ),
      );

    my $dataTable =
    {
        tableName          => 'Certificates',
        printableTableName => __('Services Certificates'),
        printableRowName   => __('certificate'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        sortedBy           => 'module',
        modelDomain        => 'CA',
        help               => __('Here you may set certificates from this CA for those '
                                 . 'secure services managed by Zentyal'),
    };

    return $dataTable;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;
    if ($action eq 'update') {
        if (exists $params_r->{cn}) {
            if (not $actual_r->{allowCustomCN}->value()) {
                throw EBox::Exceptions::External(
                    __('This service does not allow to change the certificate common name')
                   );
            }
        }
    }

    my $commonName = $actual_r->{cn}->value();
    # remove first asterisk to allow wildcard names
    $commonName =~ s/^\*\.//;
    EBox::Validate::checkDomainName($commonName, $actual_r->{cn}->printableName());
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    my $cn = $row->valueByName('cn');
    $self->_openchangeWarning($cn);

    if ($row->isEqualTo($oldRow)) {
        # no need to set module as changed
        return;
    }

    if (not $self->caAvailable()) {
        return;
    }

    my $modName = $row->valueByName('module');
    my $mod = EBox::Global->modInstance($modName);
    $mod->setAsChanged();
}

# Method: notifiyNewCA
#
# To be called to execute the needed actions when a new CA is created.
# The needed actions are to mark modules with custom certificates as
# changed, so they can set up the certificates.
sub notifyNewCA
{
    my ($self) = @_;
    for my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        if ($row->valueByName('enable')) {
            my $modName = $row->valueByName('module');
            my $mod = $self->global()->modInstance($modName);
            $mod->setAsChanged();    
        }
    }
}
    
sub _openchangeWarning
{
    my ($self, $cn) = @_;
    my $openchange = $self->parentModule()->global()->modInstance('openchange');
    if ($openchange and $openchange->certificateIsReserved($cn)) {
        my $warnMsg = __x('The CN {cn} is reserved by OpenChange and cannot be generated automatically. You can issue it from the {oh}OpenChange virtual domains interface.{ch}', 
                   cn => $cn,
                   oh => "<a href='/Mail/OpenChange'>",
                   ch => '</a>');
        $self->setMessage($warnMsg, 'warning');
    }
}

1;
