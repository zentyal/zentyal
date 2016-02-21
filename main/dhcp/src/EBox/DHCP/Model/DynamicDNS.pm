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
# Class: EBox::DHCP::Model::DynamicDNS
#
# This class is the model to configurate dynamic DNS options for DHCP
# server and DNS server on a static interface. The fields are the following:
#
#     - enabled
#     - dynamic domain
#     - static domain
#
package EBox::DHCP::Model::DynamicDNS;

use base 'EBox::Model::DataForm';

use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::View::Customizer;
use TryCatch;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the dynamic DNS options to the DHCP server
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::DHCP::Model::DynamicDNS>
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#     argument is missing
#
sub new
{
    my $class = shift;

    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    unless (defined($self->{parent})) {
        $self->{parent} = $self->parentModule()->model('Interfaces');
    }

    return $self;
}

# Method: precondition
#
# Overrides:
#
#   <EBox::Model::Component::precondition>
#
sub precondition
{
    my $gl = EBox::Global->getInstance();
    if ($gl->modExists('dns')) {
        my $dns = $gl->modInstance('dns');
        return $dns->configured();
    }
    return 0;
}

# Method: preconditionFailMsg
#
# Overrides:
#
#   <EBox::Model::Component::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my $gl = EBox::Global->getInstance();
    if ($gl->modExists('dns')) {
        my $dns = $gl->modInstance('dns');
        unless ($dns->configured()) {
            return __('DNS module must be configured to work with this feature');
        }
    } else {
        return __x('{pkg} must be installed to use this feature', pkg => 'zentyal-dns');
    }
}

# Method: viewCustomizer
#
#   Overrides this to warn the user about the usage of this feature
#   depends on ebox-dns module to work and it has to be enabled to work.
#
# Overrides:
#
#   <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    my $gl = EBox::Global->getInstance();
    if ($gl->modExists('dns')) {
        my $dns = $gl->modInstance('dns');
        unless ( $dns->isEnabled() ) {
            my $msg = __('DNS module must be enabled to make this feature work.');
            $customizer->setPermanentMessage($msg);
        }
    }

    $customizer->setHTMLTitle([]);

    return $customizer;
}

# Method: isIdUsed
#
#     Override to notify that we are using DNS domains for Dynamic DNS
#     options
#
# Overrides:
#
#     <EBox::Model::DataTable::isIdUsed>
#
sub isIdUsed
{
    my ($self, $modelName, $id) = @_;

    return unless ($modelName =~ m:dns/DomainTable:);

    my $modelRow = $self->row();
    my $dynamicDomain = $modelRow->valueByName('dynamic_domain');
    my $staticDomain = $modelRow->valueByName('static_domain');
    if (($id eq $dynamicDomain) or ($id eq $staticDomain)) {
        return 1;
    }
    return 0;
}

# Method: notifyForeignModelAction
#
#     Disable DynamicDNS configuration for this model if the domain is
#     deleted from the interface or from another interface in DHCP
#     configuration
#
# Overrides:
#
#     <EBox::Model::DataTable::notifyForeignModelAction>
#
sub notifyForeignModelAction
{
    my ($self, $model, $action, $row) = @_;
    if ($model ne 'dns/DomainTable') {
        return;
    }

    # TODO: update action is not yet supported, since we do not have
    # the old row to check the usage of the domain, currently, it is
    # not possible to edit a dynamic domain
    if ($action eq 'del') {
        my $domainId = $row->id();
        my $modelRow = $self->row();
        my $dynamicDomain = $modelRow->valueByName('dynamic_domain');
        my $staticDomain = $modelRow->valueByName('static_domain');
        if (($domainId eq $dynamicDomain) or ($domainId eq $staticDomain)) {
            # Disable the dynamic DNS feature, in formSubmitted we
            # have to enable again (:-S)
            if ($modelRow->valueByName('enabled')) {
                $modelRow->elementByName('enabled')->setValue(0);
                $modelRow->store();
                return __x('Dynamic DNS feature has been disabled in DHCP module '
                           . 'in {iface} interface.',
                           iface => $self->_iface()
                         );
            }
        }
    }
    return '';
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
       new EBox::Types::Select(
           fieldName     => 'dynamic_domain',
           printableName => __('Dynamic domain'),
           editable      => 1,
           help          => __('Domain name appended to the hostname from those clients '
                               . 'whose leased IP address comes from a range'),
           foreignModel  => $self->modelGetter('dns', 'DomainTable'),
           foreignField  => 'domain',
           foreignNoSyncRows => 1,
          ),
       new EBox::Types::Union(
           fieldName     => 'static_domain',
           printableName => __('Static domain'),
           editable      => 1,
           help          => __('Domain name appended to the hostname from those clients '
                               . 'with a fixed address mapping'),
           subtypes      => [
               new EBox::Types::Union::Text(
                   fieldName => 'same',
                   printableName => __('Same as Dynamic Domain'),
                   ),
               new EBox::Types::Select(
                   fieldName     => 'custom',
                   printableName => __('Custom'),
                   editable      => 1,
                   foreignModel  => $self->modelGetter('dns', 'DomainTable'),
                   foreignField  => 'domain',
                   foreignNoSyncRows => 1,
                  ),
              ]),
      );

      my $dataForm = {
                      tableName          => 'DynamicDNS',
                      printableTableName => __('Dynamic DNS Options'),
                      modelDomain        => 'DHCP',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                      help               => __('The domains will be added automatically to '
                                               . 'DNS module in read-only mode'),
                      # The support may be enabled or not
                      enableProperty     => 1,
                     };

    return $dataForm;
}

sub _iface
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->valueByName('iface');
}

sub dynamicDomainsIds
{
    my ($self) = @_;
    my $row = $self->row();
    if (not $row->valueByName('enabled')) {
        return [];
    }

    my @domains;
    push @domains, $row->valueByName('dynamic_domain');
    my $static = $row->elementByName('static_domain');
    if ($static->selectedType() ne 'same') {
        push @domains, $static->value();
    }

    return \@domains;
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow) = @_;
    if ($row->isEqualTo($oldRow)) {
        # no need to set module as changed
        return;
    }

    if (EBox::Global->modExists('dns')) {
        my $dnsModule = EBox::Global->modInstance('dns');
        $dnsModule->setAsChanged();
    }
}

1;
