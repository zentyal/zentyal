# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::DHCP::Model::ThinClientOptions
#
# This class is the model to configurate thin client options for the dhcp
# server on a static interface. The fields are the following:
#
#     - next server, which tells dhcp client where to search the
#     terminal server
#
#     - filename, which indicates the firmware to load when the DHCP
#     client loads
#

package EBox::DHCP::Model::ThinClientOptions;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::Config;
use EBox::DHCP;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::NetWrappers;
use EBox::Types::File;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::HostIP;
use EBox::Types::DomainName;
use EBox::Validate;

# Group: Public methods

# Constructor: new
#
#     Create the thin client options to the dhcp server
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
#     <EBox::DHCP::Model::ThinClientOptions>
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

}

# Method: formSubmitted
#
#       When the form is submitted, the model must set up the jabber
#       dispatcher client service and sets the output rule in the
#       firewall
#
# Overrides:
#
#      <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
  {

      my ($self, $oldRow) = @_;

  }

# Method: nextServer
#
#     Get the next server (name or IP address) in an string form to
#     tell the DHCP clients which is the next server to ask for
#     terminal
#
# Returns:
#
#     String - a name, an IP address or empty string if none is
#     defined
#
sub nextServer
{
    my ($self) = @_;

    my $row = $self->row();

    my $nextServerType = $row->{valueHash}->{nextServer};
    my $nextServerSelectedName = $nextServerType->selectedType();
    if ( $nextServerSelectedName eq 'nextServerNone' ) {
        return '';
    } else {
        return $nextServerType->printableValue();
    }

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
       new EBox::Types::File(
                             fieldName     => 'filename',
                             printableName => __('File name'),
                             editable      => 1,
                             optional      => 1,
                             filePath      => EBox::DHCP->ConfDir($self->{interface}) . 'firmware',
                             showFileWhenEditing => 1,
                             allowDownload => 1,
                            ),
       new EBox::Types::Union(
                              fieldName     => 'nextServer',
                              printableName => __('Next server'),
                              editable      => 1,
                              subtypes      =>
                              [new EBox::Types::Union::Text(fieldName     => 'nextServerNone',
                                                            printableName => __('None'),
                                                           ),
                               new EBox::Types::HostIP(fieldName     => 'nextServerIP',
                                                       printableName => __('IP address'),
                                                       editable      => 1,
                                                      ),
                               new EBox::Types::DomainName(fieldName     => 'nextServerName',
                                                           printableName => __('name'),
                                                           editable      => 1,
                                                          ),
                              ]),
      );

    my $dataForm = {
                    tableName          => 'ThinClientOptions',
                    printableTableName => __('Thin client'),
                    modelDomain        => 'DHCP',
                    defaultActions     => [ 'editField', 'changeView' ],
                    tableDescription   => \@tableDesc,
                    class              => 'dataForm',
                    help               => __x('You may want to customise your thin client options.'
                                             . 'To do so, you may include all the files you require '
                                             . 'under {path} directory',
                                             path => EBox::DHCP->PluginConfDir($self->{interface})),
                   };

    return $dataForm;

}

1;
