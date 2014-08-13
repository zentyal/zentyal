# Copyright (C) 2011-2014 Zentyal S.L.
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

package EBox::L2TP::Model::Connections;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HasMany;
use EBox::Types::Select;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::InvalidType;
use EBox::Samba::Group;

use TryCatch::Lite;
no warnings 'experimental::smartmatch';
use feature "switch";
use Net::IP;

use constant L2TP_PREFIX => 'zentyal-xl2tpd.';

# Method: tunnels
#
#  returns all tunnels as hashes which contains their properties
#
# Parameters:
#  includeDisabled - return also the disabled tunnels  (defauls false)
sub tunnels
{
    my ($self, $includeDisabled) = @_;

    my $network = $self->global()->modInstance('network');
    my @tunnels;

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $enabled = $row->valueByName('enabled');
        my $conf = $row->elementByName('configuration')->foreignModelInstance();
        if (not $enabled) {
            if (not $includeDisabled) {
                next;
            }
            my $configured;
            try {
                $conf->checkConfigurationIsComplete();
                $configured = 1;
            } catch {
            }
            if (not $configured) {
                next;
            }
        }
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
        $settings{'enabled'} = $enabled;
        $settings{'name'} = $row->valueByName('name');
        $settings{'comment'} =  $row->valueByName('comment');

        push @tunnels, \%settings;
    }

    return \@tunnels;
}

# Method l2tpDaemons
#
# return all l2tp daemons in the format required by _daemons method
sub l2tpDaemons
{
    my ($self) = @_;

    my @daemons = map {
        my $tunnel = $_;
        $tunnel->{name} = L2TP_PREFIX . $tunnel->{name};
        $tunnel->{type} = 'upstart';
        $tunnel->{precondition} = sub {
            return $tunnel->{enabled};
        };
        ($tunnel)
    } @{ $self->tunnels(1) };

    return \@daemons;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $samba = $self->global()->modInstance('samba');
    my $domainSID = $samba->ldap()->domainSID();
    my $domainUsers = EBox::Samba::Group->new(sid => "$domainSID-513");

    my @tableHeader = (
        new EBox::Types::Text(
            fieldName => 'name',
            printableName => __('Name'),
            size => 12,
            unique => 1,
            editable => 1,
        ),
        new EBox::Types::HasMany(
            fieldName => 'configuration',
            printableName => __('Configuration'),
            foreignModel => 'ConnectionSettings',
            view => '/L2TP/View/ConnectionSettings',
            backView => '/L2TP/View/Connections',
        ),
        new EBox::Types::HasMany(
            fieldName => 'ranges',
            printableName => __('Ranges'),
            foreignModel => 'RangeTable',
            view => '/L2TP/View/RangeTable',
            backView => '/L2TP/View/Connections',
        ),
        new EBox::Types::Select(
            fieldName     => 'group',
            printableName => __('Users Group'),
            populate      => \&_populateGroups,
            editable      => 1,
            optional      => 0,
            disableCache  => 1,
            defaultValue  => $domainUsers->name(),
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
        pageTitle => __('L2TP'),
        printableTableName => __('Connections'),
        printableRowName => __('L2TP connection'),
        defaultActions => ['add', 'del', 'editField', 'changeView' ],
        tableDescription => \@tableHeader,
        class => 'dataTable',
        modelDomain => 'L2TP',
        enableProperty => 1,
        defaultEnabledValue => 0,
        help => __('L2TP connections allow to deploy secure tunnels between ' .
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
            $conf->checkConfigurationIsComplete();
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

# Method: precondition
#
#   Overrid <EBox::Model::DataTable::precondition>
#
#   Num of external interfaces > 0
sub precondition
{
    my ($self) = @_;
    my $network = $self->global()->modInstance('network');
    return (scalar(@{$network->ExternalIfaces()}) > 0);
}

# Method: preconditionFailMsg
#
#   Overrid <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{

    return __x("L2TP can only be configured on interfaces tagged as 'external'"
                   . ' Check your interface '
                   . 'configuration to match, at '
                   . '{openhref}Network->Interfaces{closehref}',
               openhref  => '<a href="/Network/Ifaces">',
               closehref => '</a>');
}

sub deletedRowNotify
{
    my ($self, $row) = @_;
    my $name = L2TP_PREFIX . $row->valueByName('name');
    $self->parentModule()->addDeletedDaemon($name);
}

sub l2tpCheckDuplicateLocalIP
{
    my ($self, $ownId, $tunnelIP) = @_;
    $self->_checkDuplicates($ownId, tunnelIP => $tunnelIP);
}

sub l2tpCheckDuplicateIPRange
{
    my ($self, $ownId, $rangeId, $from, $to) = @_;
    $self->_checkDuplicates($ownId, range => "$from - $to", rangeOwnId => $rangeId);
}

sub _checkDuplicates
{
    my ($self, $ownId, %args) = @_;
    my $range;
    if ($args{tunnelIP}) {
        $range = new Net::IP($args{tunnelIP});
    } elsif ($args{range}) {
        $range = new Net::IP($args{range});
    } else {
        throw EBox::Exceptions::MissingArgument('tunnel or range');
    }

    if (not defined $ownId) {
        $ownId = '';
    }

    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);

        my $settings = $row->subModel('configuration');
        my $localIP  = $settings->value('local_ip');
        if ($localIP and $range->overlaps( Net::IP->new($localIP))) {
            if ($args{tunnelIP} and ($id ne $ownId)) {
                throw EBox::Exceptions::External(
                        __x('Tunnel IP {ip} is already in use by connection {name}',
                            ip   => $localIP,
                            name => $row->valueByName('name'))
                        );
            } elsif ($args{range}) {
                throw EBox::Exceptions::External(
                        __x('The range overlaps with tunnel IP {ip} used  by connection {name}',
                            ip   => $localIP,
                            name => $row->valueByName('name'))
                        );
            }
        }

        my $rangeTableOwnId = '';
        if ($args{range} and ($id eq $ownId)) {
            $rangeTableOwnId = $args{rangeOwnId};
        }
        my $rangeTable = $row->subModel('RangeTable');
        if ($rangeTable->rangeOverlaps($range, $rangeTableOwnId)) {
            if ($args{tunnelIP}) {
                throw EBox::Exceptions::External(
                        __x('Tunnel IP {ip} is already in use by range in connection {name}',
                            ip => $args{tunnelIP},
                            name => $row->valueByName('name'))
                        );
            } elsif ($args{range}) {
                throw EBox::Exceptions::External(
                        __x('Range {range} is already in use by connection {name}',
                            range => $args{range},
                            name => $row->valueByName('name'))
                        );
            }
        }
    }
}

# Method: _populateGroups
#
# List all available groups in the system.
#
sub _populateGroups
{
    my $usersMod = EBox::Global->modInstance('samba');

    unless ($usersMod->isEnabled() and $usersMod->isProvisioned()) {
        return [];
    }

    my @securityGroups;
    foreach my $group (@{$usersMod->ldap()->securityGroups()}) {
        my $name = $group->name();
        push (@securityGroups, {
            value => $name,
            printableValue => $name,
        });
    }
    return \@securityGroups;
}


1;
