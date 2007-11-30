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

package EBox::WebServer::Model::GeneralSettings;

# Class: EBox::WebServer::Model::GeneralSettings
#
#   Form to set the general configuration settings for the web server
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::DataExists;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Boolean;
use EBox::Types::Port;
use EBox::Validate;

# Constant
use constant PUBLIC_DIR => 'public_html';

# Group: Public methods

# Constructor: new
#
#       Create the new GeneralSettings model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::WebServer::Model::GeneralSettings> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;

}

# Method: validateTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::ValidateTypedRow>
#
# Exceptions:
#
#       <EBox::Exceptions::DataExists> - if the port number is already
#       in use by any ebox module
#
sub validateTypedRow
{

    my ($self, $action, $changedFields) = @_;

    if ( exists $changedFields->{port} and $action eq 'update') {
        my $portNumber = $changedFields->{port}->value();

        my $gl = EBox::Global->getInstance();
        my $firewall = $gl->modInstance('firewall');

        unless ( $firewall->availablePort('tcp', $portNumber) ) {
            throw EBox::Exceptions::DataExists(
                                               'data'  => __('listening port'),
                                               'value' => $portNumber,
                                              );
        }
    }

}

# Method: formSubmitted
#
# Overrides:
#
#       <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self) = @_;

    # Set the new port number in services module
    my $portNumber = $self->portValue();
    my $servMod = EBox::Global->modInstance('services');
    $servMod->updateDestPort( '/http/0', $portNumber);

}

# Group: Protected methods

# Method: _table
#
#       The table description which consists of two fields:
#
#       port        - <EBox::Types::Int>
#       enabledDir  - <EBox::Types::Boolean>
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
#
sub _table
{

    my @tableHeader =
      (
       new EBox::Types::Port(
                             fieldName     => 'port',
                             printableName => __('Listening port'),
                             editable      => 1,
                             defaultValue  => 80,
                            ),
       new EBox::Types::Boolean(
                                fieldName     => 'enableDir',
                                printableName => __x('Enable per user {dirName}',
                                                     dirName => PUBLIC_DIR),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
      );

    my $dataTable =
      {
       tableName          => 'GeneralSettings',
       printableTableName => __('General configuration settings'),
       defaultActions     => [ 'editField', 'changeView' ],
       tableDescription   => \@tableHeader,
       class              => 'dataForm',
       help               => __x('General Web server configuration. The listening port '
                                 . 'must not be got from another service. If you enable '
                                 . 'user to publish their own html pages, the pages will be '
                                 . 'loaded from {dirName} directory from their samba home directories',
                                 dirName => PUBLIC_DIR),
       messages           => {
                              update => __('General Web server configuration settings updated'),
                             },
       modelDomain        => 'WebServer',
      };

    return $dataTable;

}

1;
