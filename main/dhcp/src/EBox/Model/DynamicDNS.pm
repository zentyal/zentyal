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

use strict;
use warnings;

use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::View::Customizer;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the dynamic DNS options to the dhcp server
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Parameters:
#
#     interface - String the interface where the DHCP server is
#     attached
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
    bless ( $self, $class);

    throw EBox::Exceptions::MissingArgument('interface')
      unless defined ( $opts{interface} );

    $self->{interface} = $opts{interface};

    return $self;

}

# Method: index
#
# Overrides:
#
#      <EBox::Model::DataTable::index>
#
sub index
{

    my ($self) = @_;

    return $self->{interface};

}

# Method: printableIndex
#
# Overrides:
#
#     <EBox::Model::DataTable::printableIndex>
#
sub printableIndex
{

    my ($self) = @_;

    return __x("interface {iface}",
              iface => $self->{interface});

}


# Method: formSubmitted
#
#       When the form is submitted, do something
#
# Overrides:
#
#      <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self, $oldRow) = @_;

    # We assume the DNS module exists and is configured
    my $newRow = $self->row();
    my $dnsMod = EBox::Global->modInstance('dns');

    my $msg = '';
    if ($newRow->valueByName('enabled')) {
        # Manage dynamic domain
        $msg .= $self->_manageZone(newDomain => $newRow->valueByName('dynamic_domain'),
                                   oldDomain => $oldRow->valueByName('dynamic_domain'),
                                   dns => $dnsMod);

        # Manage static domain
        my ($newDomain, $oldDomain) = ($newRow->valueByName('static_domain'),
                                       $oldRow->valueByName('static_domain'));
        if ( $newRow->elementByName('static_domain')->selectedType() eq 'same' ) {
            $newDomain = undef;
        }
        if ( $oldRow->elementByName('static_domain')->selectedType() eq 'same' ) {
            $oldDomain = undef;
        }
        if ( $msg ) {
            $msg .= '. ';
        }
        $msg .= $self->_manageZone(newDomain => $newDomain, oldDomain => $oldDomain,
                                   dns => $dnsMod);

        # Enable again if necessary for notifying other models using
        # the same previous domain
        my $currentRow = $self->row();
        $currentRow->elementByName('enabled')->setValue(1);
        $currentRow->store();

    } elsif ( $oldRow->valueByName('enabled') ) {
        # If it was enabled, remove old domains
        $msg .= $self->_manageZone(newDomain => undef,
                                   oldDomain => $oldRow->valueByName('dynamic_domain'),
                                   dns => $dnsMod);
        # Delete the static if it is different than dynamic
        if ( $oldRow->elementByName('static_domain')->selectedType() eq 'custom' ) {
            if ( $msg ) {
                $msg .= '. ';
            }
            $msg .= $self->_manageZone(newDomain => undef,
                                       oldDomain => $oldRow->valueByName('static_domain'),
                                       dns => $dnsMod);
        }
    }

    EBox::debug("message: $msg");
    $self->setMessage($msg) if ( $msg );

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
    if ( $gl->modExists('dns') ) {
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
    if ( $gl->modExists('dns') ) {
        my $dns = $gl->modInstance('dns');
        unless ( $dns->configured() ) {
            return __('DNS module must be configured to work with this feature');
        }
    } else {
        return __x('{pkg} must be installed to use this feature', pkg => 'ebox-dns');
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
    if ( $gl->modExists('dns') ) {
        my $dns = $gl->modInstance('dns');
        unless ( $dns->isEnabled() ) {
            my $msg = __('DNS module must be enabled to make this feature work.');
            $customizer->setPermanentMessage($msg);
        }

    }
    return $customizer;
}

# Method: headTitle
#
# Overrides:
#
#   <EBox::Model::Component::headTitle>
#
sub headTitle
{
    return undef;
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

    # TODO: update action is not yet supported, since we do not have
    # the old row to check the usage of the domain, currently, it is
    # not possible to edit a dynamic domain
    if ($action eq 'del') {
        if ( $row->id() eq $self->row()->valueByName('dynamic_domain')
             or $row->id() eq $self->row()->valueByName('static_domain') ) {
            # Disable the dynamic DNS feature, in formSubmitted we
            # have to enable again (:-S)
            my $row = $self->row();
            if ( $row->valueByName('enabled') ) {
                $row->elementByName('enabled')->setValue(0);
                $row->store();
                return __x('Dynamic DNS feature has been disabled in DHCP module '
                           . 'in {iface} interface.', iface => $self->index());
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
           foreignModel  => \&_domainModel,
           foreignField  => 'domain',
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
                   foreignModel  => \&_domainModel,
                   foreignField  => 'domain',
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
                      # Notify when changes in DomainTable
                      notifyActions      => [ 'DomainTable' ],
                     };

      return $dataForm;

  }

# Group: Private methods

# Add/remove the zone/domain from DNS
# Returns a message to inform the user
sub _manageZone
{
    my ($self, %args) = @_;

    my $msg = "";
    if ( defined($args{newDomain}) ) {
        my $domainRow = $args{dns}->model('DomainTable')->row($args{newDomain});
        if ( defined($domainRow) ) {
            $domainRow->elementByName('dynamic')->setValue(1);
            $domainRow->store();
            $msg = __x('Domain "{domain}" set as dynamic in DNS section',
                       domain => $domainRow->printableValueByName('domain'));
        } else {
            throw EBox::Exceptions::Internal('Trying to modify a not valid domain from dhcp module');
        }
    }
    if (defined($args{oldDomain}) and ($args{oldDomain} ne $args{newDomain})) {
        my $domainRow = $args{dns}->model('DomainTable')->row($args{oldDomain});
        if ( defined($domainRow) ) {
            $domainRow->elementByName('dynamic')->setValue(0);
            $domainRow->store();
            if ( $msg ) {
                $msg .= '. ';
            }
            $msg .= __x('Domain "{domain}" set as static in DNS section',
                        domain => $domainRow->printableValueByName('domain'));
        } # else already remove by previous caller (delete a domain from DNS)
    }
    return $msg;
}

# Get the domain model
sub _domainModel
{
    return EBox::Global->modInstance('dns')->model('DomainTable');
}

1;
