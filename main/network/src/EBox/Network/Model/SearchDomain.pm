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

package EBox::Network::Model::SearchDomain;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::DomainName;
use EBox::Types::Text;
use Error qw( :try );

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the DynDNS model
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::Network::Model::SearchDomain>
#
sub new
{
      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless ( $self, $class );

      return $self;
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

    my $tableHeader = [
        new EBox::Types::DomainName(
            fieldName     => 'domain',
            printableName => __('Domain'),
            editable      => 1,
            optional      => 1),
        new EBox::Types::Text(
            fieldName       => 'interface',
            printableName   => __('Interface'),
            editable        => 0,
            optional        => 1,
            hidden          => 1),
    ];

    my $dataTable = {
        tableName          => 'SearchDomain',
        printableTableName => __('Search Domain'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => $tableHeader,
        class              => 'dataForm',
        help               => __('This domain will be appended when trying '
                                . 'to resolve hosts if the first attempt '
                                . 'without appending it has failed.'),
        modelDomain        => 'Network',
    };

    return $dataTable;
}

# Method: updatedRowNotify
#
#   This method is overrided to update the interface field.
#
#   When search domain is updated from the resolvconf update script
#   (/etc/resolvconf/update.d/zentyal-resolvconf), the interface field is
#   populated with the value used by the network configurer daemon
#   (ifup, ifdown, etc). Otherwise, we fill with the value "zentyal_<row id>"
#
# Overrides:
#
#   <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row) = @_;

    my $interfaceElement = $row->elementByName('interface');
    my $id = 'zentyal.' . $row->id();
    if ($interfaceElement->value() ne $id) {
        $interfaceElement->setValue($id);
        $row->store();
    }
}

# Method: importSystemSearchDomain
#
#   This method populate the model with the currently configured search
#   domains
#
sub importSystemSearchDomain
{
    my ($self) = @_;

    try {
        # Change directory to /var/run/resolvconf/interface
        chdir '/var/run/resolvconf/interface';

        # Call to /lib/resolvconf/list-records to get the list ordered by
        # the rules in /etc/resolvconf/interface-order
        my $files = `/lib/resolvconf/list-records`;
        my @files = split(/\n/, $files);

        # Read each file and parse search
        my %domains;
        foreach my $file (@files) {
            my $fd;
            unless (open ($fd, $file)) {
                EBox::warn("Couldn't open $file");
                next;
            }

            $domains{$file} = [];
            for my $line (<$fd>) {
                $line =~ s/^\s+//g;
                my @toks = split (/\s+/, $line);
                if (($toks[0] eq 'domain') or ($toks[0] eq 'search')) {
                    push (@{$domains{$file}}, $toks[1]);
                }
            }
            close ($fd);
        }

        # Populate the table with the obtained information
        $self->removeAll(1);

        foreach my $interface (keys %domains) {
            foreach my $domain (@{$domains{$interface}}) {
                $self->setValue('interface', $interface);
                $self->setValue('domain', $domain);
            }
        }
    } otherwise {
        my ($error) = @_;
        EBox::error("Could not import search domain: $error");
    };
}

1;
