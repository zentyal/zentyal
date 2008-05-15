# Copyright (C) 2008 Warp Networks S.L.
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

# Class:
#
#   EBox::DNS::Model::MailExchanger
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the object table which contains the mail exchangers for a domain
#   with its preference value. A member of
#   <EBox::DNS::Model::DomainTable>
#
package EBox::DNS::Model::MailExchanger;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::DomainName;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Types::Union;

use EBox::Model::ModelManager;

use constant {
    MIN_PREFERENCE_NUM => 0,
    MAX_PREFERENCE_NUM => 65535,
};

# Group: Public methods

# Constructor: new
#
#      Create a new MailExchanger model instance
#
# Returns:
#
#      <EBox::DNS::Model::MailExchanger> - the newly created model
#      instance
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless($self, $class);

    return $self;
}

# Method: validateTypedRow
#
#   Check the preference number is a valid one
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if ( exists $changedFields->{preference} ) {
        my $prefVal = $changedFields->{preference}->value();
        unless ( $prefVal > MIN_PREFERENCE_NUM and $prefVal < MAX_PREFERENCE_NUM ) {
            throw EBox::Exceptions::External(__x('Invalid preference number. Allowed range: ({min}, {max})',
                                                 min => MIN_PREFERENCE_NUM,
                                                 max => MAX_PREFERENCE_NUM));
        }
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
          new EBox::Types::Union(
                                 fieldName     => 'hostName',
                                 printableName => __('Host name'),
                                 editable      => 1,
                                 unique        => 1,
                                 subtypes      =>
                                 [
                                  new EBox::Types::Select(
                                                          fieldName     => 'ownerDomain',
                                                          printableName => __('Owner domain'),
                                                          foreignModel  => \&_hostnameModel,
                                                          foreignField  => 'hostname',
                                                          editable      => 1,
                                                          unique        => 1,
                                                         ),
                                  new EBox::Types::DomainName(
                                                              fieldName     => 'custom',
                                                              printableName => __('Custom'),
                                                              editable      => 1,
                                                              unique        => 1,
                                                             ),
                                 ],
                                ),
            new EBox::Types::Int(
                                 fieldName     => 'preference',
                                 printableName => __('Preference'),
                                 editable      => 1,
                                 defaultValue  => 10,
                                ),
      );

    my $dataTable =
        {
            tableName => 'MailExchanger',
            printableTableName => __('Mail exchangers'),
            automaticRemove => 1,
            modelDomain     => 'DNS',
            defaultActions => ['add', 'del', 'editField',  'changeView' ],
            tableDescription => \@tableDesc,
            class => 'dataTable',
            help => __x('The smallest preference number has the highest priority '
                        . ' and is the first server to be tried when a remote client '
                        . '(typically another mail server) does an MX lookup for the '
                        . 'domain name. Allowed preference number interval = ({min}, {max})',
                        min => MIN_PREFERENCE_NUM,
                        max => MAX_PREFERENCE_NUM),
            printableRowName => __('Mail exchanger record'),
            sortedBy => 'preference',
        };

    return $dataTable;
}

# Group: Private methods

# Get the hostname model from DNS module
sub _hostnameModel
{
    my ($type) = @_;

    # FIXME: Change the directory
    my $model = EBox::Global->modInstance('dns')->model('HostnameTable');
    my $dir = $type->model()->directory();
    # Substitute mailExchangers name for hostnames to set the correct directory in hostname table
    $dir =~ s:mailExchangers:hostnames:g;
    $model->setDirectory($dir);
    return $model;
}

1;
