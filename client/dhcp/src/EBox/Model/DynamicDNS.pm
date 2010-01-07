# Copyright (C) 2009 eBox Technologies S.L.
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

# eBox uses
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::DomainName;
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

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if ( exists($changedFields->{dynamic_domain}) or exists($changedFields->{static_domain}) ) {
        my $dnsMod = EBox::Global->modInstance('dns');
        my $domains = $dnsMod->domains();
        if ( exists($changedFields->{dynamic_domain}) ) {
            my ($domData) = grep { $_->{name} eq $changedFields->{dynamic_domain}->value() } @{$domains};
            if ( defined($domData) and (not($domData->{dynamic})) ) {
                throw EBox::Exceptions::External(__x('Domain {domain} has already been defined '
                                                       . 'manually in DNS section', domain => $domData->{name}));
            }
        }
        if ( exists($changedFields->{static_domain}) ) {
            if ( $changedFields->{static_domain}->selectedType() eq 'custom' ) {
                my ($domData) = grep { $_->{name} eq $changedFields->{static_domain}->value() } @{$domains};
                if ( defined($domData) and (not($domData->{dynamic})) ) {
                    throw EBox::Exceptions::External(__x('Domain {domain} has already been defined '
                                                           . 'manually in DNS section', domain => $domData->{name}));
                }
            }
        }
    }

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
    my $domains = $dnsMod->domains();
    my $msg = '';
    if ($newRow->valueByName('enabled')) {
        # Manage dynamic domain
        $msg .= $self->_manageZone(newDomain => $newRow->valueByName('dynamic_domain'),
                                   oldDomain => $oldRow->valueByName('dynamic_domain'),
                                   dns => $dnsMod, domainsData => $domains);

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
        $msg .= $self->_manageZone(newDomain => $newDomain, oldDomain => $oldDomain, dns => $dnsMod,
                                   domainsData => $domains);
    } elsif ( $oldRow->valueByName('enabled') ) {
        # If it was enabled, remove old domains
        $msg .= $self->_manageZone(newDomain => undef,
                                   oldDomain => $oldRow->valueByName('dynamic_domain'),
                                   dns => $dnsMod, domainsData => $domains);
        # Delete the static if it is different than dynamic
        if ( $oldRow->elementByName('static_domain')->selectedType() eq 'custom' ) {
            if ( $msg ) {
                $msg .= '. ';
            }
            $msg .= $self->_manageZone(newDomain => undef,
                                       oldDomain => $oldRow->valueByName('static_domain'),
                                       dns => $dnsMod, domainsData => $domains);
        }
    }

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
        my $msg = __('Domains will be added/set automatically in DNS section in read-only mode.');
        unless ( $dns->isEnabled() ) {
            $msg .= ' ' . __('DNS module must be enabled to make this feature work. ');
        }
        $customizer->setPermanentMessage($msg);
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
       new EBox::Types::DomainName(
           fieldName     => 'dynamic_domain',
           printableName => __('Dynamic domain'),
           editable      => 1,
           help          => __('Domain name appended to the hostname from those clients '
                               . 'whose leased IP address comes from a range'),
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
               new EBox::Types::DomainName(
                   fieldName     => 'custom',
                   printableName => __('Custom'),
                   editable      => 1,
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

# Group: Private methods

# Add/remove the zone/domain from DNS
# Returns a message to inform the user
sub _manageZone
{
    my ($self, %args) = @_;

    my $msg = "";
    if ( defined($args{newDomain}) ) {
        my ($domData) = grep { $_->{name} eq $args{newDomain} } @{$args{domainsData}};
        if ( defined($domData) and (not($domData->{dynamic})) ) {
            throw EBox::Exceptions::External(__x('Domain {domain} has already been defined '
                                                   . 'manually in DNS section', domain => $domData->{name}));
        } elsif ( not defined($domData) ) {
            # Add the new domain as dynamic
            my $addedId = $args{dns}->addDomain1(domain  => $args{newDomain}, dynamic => 1);
            my $domRow = $args{dns}->model('DomainTable')->row($addedId);
            $domRow->setReadOnly(1);
            $domRow->store();
            $msg = __x('Domain "{domain}" added to DNS section', domain => $args{newDomain});
        }
    }
    if (defined($args{oldDomain}) and ($args{oldDomain} ne $args{newDomain})) {
        my ($domData) = grep { $_->{name} eq $args{oldDomain} } @{$args{domainsData}};
        if ( defined($domData) ) {
            if ( $domData->{dynamic} ) {
                $args{dns}->removeDomain($args{oldDomain});
                if ( $msg ) {
                    $msg .= '. ';
                }
                $msg .= __x('Domain "{domain}" removed from DNS section', domain => $args{oldDomain});
            } else {
                throw EBox::Exceptions::Internal('Trying to remove a static domain from dhcp module');
            }
        }
    }
    return $msg;
}

1;
