# Copyright (C) 2009-2010 eBox Technologies S.L.
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


package EBox::CA::Model::Certificates;

# Class: EBox::CA::Model::Certificates
#
#      Form to set the rollover certificates for modules
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Types::DomainName;
use EBox::Types::Boolean;
use EBox::CA;

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


# Method: precondition
#
#   Check if CA has been created.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $ca = EBox::Global->modInstance('ca');

    return $ca->isAvailable();
}


# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail.
#
# Overrides:
#
#       <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;

    return __x('You must create a Certification Authority first. '
              . 'Go to {openhref}Certification Authority{closehref} to do so',
              openhref  => qq{<a href='/ebox/CA/Index'>},
              closehref => qq{</a>});
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
    my %currentSrvs = map { $self->row($_)->valueByName('service') => 1 } @{$currentRows};

    my @srvsToAdd = grep { not exists $currentSrvs{$_->{'service'}} } @srvs;

    my $modified = 0;
    for my $srv (@srvsToAdd) {
        my $cn = exists $srv->{'defaultCN'} ? $srv->{'defaultCN'} : 'Zentyal';
        my $allowCustomCN = exists $srv->{allowCustomCN} ?
                                       $srv->{allowCustomCN}  : 1;
        $self->add(module => $srv->{'module'},
                   service => $srv->{'service'},
                   cn => $cn,
                   allowCustomCN => $allowCustomCN,
                   enable => 0);
        $modified = 1;
    }

    my %srvsToAdd = map { $_->{service} => 1 } @srvs;
    for my $id (@{$currentRows}) {
        my $currentService = $self->row($id)->valueByName('service');
        unless (exists $srvsToAdd{$currentService}) {
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
    my ($self, $service) = @_;

    my $row = $self->find(service => $service);
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
    my ($self, $service, $ro) = @_;

    my $row = $self->find(service => $service);
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
    my ($self, $service, $cn) = @_;

    my $row = $self->find(service => $service);
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
    my ($self, $service) = @_;

    my $row = $self->find(service => $service);
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
    my ($self, $service) = @_;

    my $row = $self->find(service => $service);
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
                                fieldName     => 'module',
                                printableName => __('Module'),
                                unique        => 0,
                                editable      => 0,
                                filter => sub {
                                    my ($self)  = @_;
                                    my $modName = $self->value();
                                    my $mod = EBox::Global->modInstance($modName);
                                    return $mod->title();
                                },
                               ),
       new EBox::Types::Text(
                                fieldName     => 'service',
                                printableName => __('Service'),
                                unique        => 1,
                                editable      => 0,
                               ),
       new EBox::Types::DomainName(
                                fieldName     => 'cn',
                                printableName => __('Common Name'),
                                unique        => 0,
                                editable      => 1,
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
                    __('This service does not allow to change the  certifcate  common name')
                   );
            }
        }
    }
}

sub updatedRowNotify
{
    my ($self, $row) = @_;
    my $modName = $row->valueByName('module');
    my $mod = EBox::Global->modInstance($modName);
    $mod->setAsChanged();

}

1;
