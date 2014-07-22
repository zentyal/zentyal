# Copyright (C) 2014 Zentyal S.L.
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

# Class:
#
#   EBox::DNS::Model::ReverseZones
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the object table which contains reverse zones
#
package EBox::DNS::Model::ReverseZones;

use base 'EBox::DNS::Model::ZoneTable';

use EBox::Gettext;
use EBox::DNS::Types::ReverseDnsZone;
use EBox::Types::Boolean;
use EBox::Types::DomainName;
use EBox::Types::HasMany;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Composite;
use EBox::Types::Select;

use EBox::DNS::View::DomainTableCustomizer;

# Group: Public methods

# Group: Protected methods

# Method: viewCustomizer
#
#   Use our own customizer to hide dynamic field in add form
#
# Overrides:
#
#   <EBox::Model::Component::viewCustomizer>
#
#sub viewCustomizer
#{
#    my ($self) = @_;
#
#    my $customizer = new EBox::DNS::View::DomainTableCustomizer();
#    $customizer->setModel($self);
#    return $customizer;
#}

# Method: addedRowNotify
#
#    Override to:
#       - Generate the TSIG key
#
# Overrides:
#
#    <EBox::Model::DataTable::addedRowNotify>
#
sub addedRowNotify
{
    my ($self, $newRow) = @_;

    # Generate the TSIG key
    my $secret = $self->generateSecret();
    my $secretElement = $newRow->elementByName('tsigKey');
    $secretElement->setValue($secret);
    $newRow->store();
}

sub defaultPrimaryNameServer
{
    my ($self) = @_;

    my $global = $self->global();
    my $sysinfo = $global->modInstance('sysinfo');
    return $sysinfo->fqdn();
}

sub defaultHostMaster
{
    my ($self) = @_;

    my $global = $self->global();
    my $sysinfo = $global->modInstance('sysinfo');
    my $domain = $sysinfo->hostDomain();

    return "hostmaster.$domain";
}

sub _table
{
    my ($self) = @_;

    my $tableHead = [
        new EBox::DNS::Types::ReverseDnsZone(
            fieldName       => 'rzone',
            printableName   => __('Reverse zone'),
            size            => '25',
            unique          => 1,
            editable        => 1
        ),
        new EBox::Types::Union(
            fieldName       => 'primaryNameServer',
            printableName   => __('Primary name server'),
            unique          => 0,
            editable        => 1,
            subtypes        => [
                new EBox::Types::Text(
                    fieldName       => 'default',
                    printableName   => __('Default'),
                    defaultValue    => sub { $self->defaultPrimaryNameServer() },
                ),
                new EBox::Types::DomainName(
                    fieldName       => 'custom',
                    printableName   => __('Custom'),
                    editable        => 1,
                ),
            ],
        ),
        new EBox::Types::Text(
            fieldName       => 'hostmaster',
            printableName   => __('Host master'),
            size            => '25',
            unique          => 0,
            editable        => 1,
            defaultValue    => sub { $self->defaultHostMaster() },
        ),
        new EBox::Types::HasMany(
            fieldName       => 'hosts',
            printableName   => __('Hosts'),
            foreignModel    => 'ReverseHosts',
            view            => '/DNS/View/ReverseHosts',
            backView        => '/DNS/View/ReverseZones',
            size            => '1',
        ),
        new EBox::Types::HasMany(
            fieldName       => 'nameServers',
            printableName   => __('Name servers'),
            foreignModel    => 'ReverseNameServers',
            view            => '/DNS/View/ReverseNameServers',
            backView        => '/DNS/View/ReverseZones',
            size            => '1',
        ),
        # This field indicates if the domain is static, dynamic or dlz
        # Not editable from interface
        new EBox::Types::Boolean(
            fieldName      => 'dynamic',
            printableName  => __('Dynamic domain'),
            editable       => 0,
            defaultValue   => 0,
            hiddenOnSetter => 1,
            hiddenOnViewer => 0,
            HTMLViewer     => '/dns/ajax/viewer/dynamicDomainViewer.mas'
        ),
        new EBox::Types::Text(
            fieldName       => 'tsigKey',
            editable        => 0,
            optional        => 1,
            hidden          => 1,
        ),
#        new EBox::Types::Boolean(
#            fieldName      => 'managed',
#            editable       => 0,
#            optional       => 0,
#            defaultValue   => 0,
#            hidden         => 1,
#        ),
        new EBox::Types::Boolean(
            fieldName      => 'samba',
            editable       => 0,
            optional       => 0,
            defaultValue   => 0,
            hidden         => 1,
        ),
    ];

    # TODO Change help message
    my $helpMsg = __('Here you can add the domains for this DNS server. ' .
                     'each domain can have different hostnames with aliases ' .
                     ' (A and CNAME) and other special records (MX, NS, TXT and SRV).');

    my $dataTable = {
        tableName           => 'ReverseZones',
        printableTableName  => __('Reverse zones'),
        automaticRemove     => 1,
        defaultController   => '/Dns/Controller/ReverseZones',
        HTTPUrlView         => 'DNS/Composite/Global',
        defaultActions      => ['add', 'del', 'editField',  'changeView' ],
        tableDescription    => $tableHead,
        class               => 'dataTable',
        printableRowName    => __('reverse zone'),
        sortedBy            => 'rzone',
        help                => $helpMsg,
    };

    return $dataTable;
}

# Method: syncRows
#
#   Needed to mark zones as dynamic
#
#   TODO Read samba and update
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
#sub syncRows
#{
#    my ($self, $currentIds) = @_;
#
#    return 0;
#}

1;
