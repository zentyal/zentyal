# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::IPsec::Model::Connections;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HasMany;
use EBox::Types::Select;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::InvalidType;

use TryCatch::Lite;
use feature "switch";

# Group: Public methods

sub tunnels
{
    my ($self) = @_;

    my $network = $self->global()->modInstance('network');
    my @tunnels;

    foreach my $id (@{$self->enabledRows()}) {
        my $row = $self->row($id);
        my $conf = $row->elementByName('configuration')->foreignModelInstance();
        my $type = $row->valueByName('type');
        my @confComponents;

        @confComponents = @{$conf->models(1)};

        my %settings;
        foreach my $component (@confComponents) {
            if ($component->isa('EBox::Model::DataForm')) {
                my $elements = $component->row()->elements();

                foreach my $element (@{ $elements }) {
                    my $fieldName = $element->fieldName();
                    my $fieldValue;

                    given ($fieldName) {
                        when (/^right$/) {
                            if ($element->selectedType() eq 'right_any') {
                                $fieldValue = '%any';
                            } else {
                                # Value returns array with (ip, netmask)
                                $fieldValue = join ('/', $element->value());
                            }
                            $fieldName = 'right_ipaddr'; # this must be the property
                                                         # value name
                        }
                        when (/^primary_ns$/) {
                            $fieldValue = $component->nameServer(1);
                        }
                        when (/^wins_server$/) {
                            $fieldValue = $component->winsServer();
                        }
                        default {
                            if ($element->value()) {
                                # Value returns array with (ip, netmask)
                                $fieldValue = join ('/', $element->value());
                            } else {
                                $fieldValue = undef;
                            }
                        }
                    }
                    $settings{$fieldName} = $fieldValue;
                }

            } elsif ($component->isa('EBox::Model::DataTable')) {
                given ($component->name()) {
                    when (/^RangeTable$/) {
                        my @ranges = ();
                        foreach my $rowid (@{$component->ids()}) {
                            my $row = $component->row($rowid);
                            push @ranges, join ('-', ($row->valueByName('from'), $row->valueByName('to')));
                        }
                        $settings{'ip_range'} = join (',', @ranges);
                    }
                    when (/^UsersFile/) {
                        EBox::debug("UsersFile model is not handled with the tunnel information.");
                    }
                    default {
                        throw EBox::Exceptions::InvalidData(
                            data => __('DataTable Component'),
                            value => $component->name(),
                            advice => __('Don\'t know how to handle this component.'),
                        );
                    }
                }
            } else {
                throw EBox::Exceptions::InvalidType(
                    data => __('Component'),
                    value => $component->name(),
                    advice => __('Unknown'),
                );
            }
        }
        $settings{'name'} = $row->valueByName('name');
        $settings{'type'} = $type;
        $settings{'comment'} =  $row->valueByName('comment');

        push @tunnels, \%settings;
    }

    return \@tunnels;
}

# Group: Private methods

sub _populateType
{
    my @opts = ();

    push (@opts, { value => 'l2tp', printableValue => 'L2TP/IPSec PSK' });
    push (@opts, { value => 'ipsec', printableValue => 'IPSec PSK' });

    return \@opts;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
        new EBox::Types::Text(
            fieldName => 'name',
            printableName => __('Name'),
            size => 12,
            unique => 1,
            editable => 1,
        ),
        new EBox::Types::Select(
            fieldName => 'type',
            printableName => __('Type'),
            editable => 1,
            populate => \&_populateType,
            help => __('The type of IPSec VPN.'),
        ),
        new EBox::Types::HasMany(
            fieldName     => 'configuration',
            printableName => __('Configuration'),
            foreignModelIsComposite => 1,
            foreignModelAcquirer => \&acquireVPNConfigurationModel,
            backView => '/IPsec/View/Connections',
        ),
        new EBox::Types::Text(
            fieldName => 'comment',
            printableName => __('Comment'),
            size => 24,
            unique => 0,
            editable => 1,
            optional => 1,
        ),
    );

    my $dataTable = {
        tableName => 'Connections',
        pageTitle => __('IPsec Connections'),
        printableTableName => __('IPsec Connections'),
        printableRowName => __('IPsec connection'),
        defaultActions => ['add', 'del', 'editField', 'changeView' ],
        tableDescription => \@tableHeader,
        class => 'dataTable',
        modelDomain => 'IPsec',
        enableProperty => 1,
        defaultEnabledValue => 0,
        help => __('IPsec connections allow to deploy secure tunnels between ' .
                   'different subnetworks. This protocol is vendor independant ' .
                   'and will connect Zentyal with other security devices.'),
    };

    return $dataTable;
}

sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if (defined $changedFields->{enabled} && $changedFields->{enabled}->value()) {
        my $row = $self->row($allFields->{id});
        if ($row) {
            # The row is already created. Otherwise is being created so there is no need to do any validation.
            my $conf = $row->elementByName('configuration')->foreignModelInstance();

            try {
                foreach my $model (@{$conf->models(1)}) {
                    foreach my $rowID (@{$model->enabledRows()}) {
                        my $row = $model->row($rowID);
                        $model->validateTypedRow('update', $row->hashElements(), $row->hashElements());
                    }
                }
            } catch {
                my $error = shift;
                throw EBox::Exceptions::InvalidData(
                    data => __('Enabled flag'),
                    value => __('Enabled'),
                    advice => __x(
                        'Cannot be enabled due to errors in the connection configuration: {error}',
                        error => $error
                    )
                );
            }
        } else {
            throw EBox::Exceptions::InvalidData(
                data => __('Enabled flag'),
                value => __('Enabled'),
                advice => __(
                    'Cannot be enabled when creating a new connection, you should edit the configuration before ' .
                    'enabling it',
                )
            );
        }
    }

    if (defined $changedFields->{name}) {
        my $name = $changedFields->{name}->value();

        if ($name =~ m/\s/) {
            throw EBox::Exceptions::InvalidData(
                data => __('Connection name'),
                value => $name,
                advice => __('Blank characters are not allowed')
            );
        }
    }
}

# Group: Callback functions

# Function: acquireVPNConfigurationModel
#
#       Callback function used to gather the foreignModel and its view
#       in order to configure the log event watcher filters
#
# Parameters:
#
#       row - hash ref with the content what is stored in GConf
#       regarding to this row.
#
# Returns:
#
#      String - the foreign model to configurate the filters
#      associated to the VPN being configured.
#
sub acquireVPNConfigurationModel
{
    my ($row) = @_;

    my $type = $row->valueByName('type');

    if ($type eq 'l2tp') {
        return 'IPsecL2TPConf';
    } elsif ($type eq 'ipsec') {
        return 'IPsecConf';
    } else {
        throw EBox::Exceptions::InvalidData(
            data => __('VPN Type'),
            value => $type,
            advice => __('Not supported'),
        );
    }
}

1;
