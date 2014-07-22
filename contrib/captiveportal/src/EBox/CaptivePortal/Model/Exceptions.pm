# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::CaptivePortal::Model::Exceptions;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Union;
use EBox::Types::Select;
use EBox::Exceptions::External;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );
    return $self;
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

    my @tableHeader = (
         new EBox::Types::Union(
                              fieldName => 'exception',
                              printableName => __('Exception'),
                              filter => \&_filterExceptionPrintableValue,
                              editable => 1,
                              subtypes => [
                                  new EBox::Types::Select(
                                      'fieldName' => 'exception_object',
                                      'printableName' => __('Object exempt'),
                                      'foreignModel' => $self->modelGetter('objects', 'ObjectTable'),
                                      'foreignField' => 'name',
                                      'foreignNextPageField' => 'members',
                                      'editable' => 1
                                     ),

                                  new EBox::Types::Select(
                                      'fieldName' => 'exception_service',
                                      'printableName' => __('Service exempt'),
                                      'foreignModel' => $self->modelGetter('services', 'ServiceTable'),
                                      'foreignField' => 'printableName',
                                      'foreignNextPageField' => 'configuration',
                                      'editable' => 1
                                     ),
                                 ],
                             ),
    );

    my $dataTable =
    {
        tableName          => 'Exceptions',
        printableTableName => __('Exceptions'),
        printableRowName   => __('exception'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        help               => __('List of services and network objects which are exempt of captive portal'),
        modelDomain        => 'CaptivePortal',
        enableProperty     => 1,
        defaultEnabledValue => 1,
    };

    return $dataTable;
}

sub validateTypedRow
{
    my ($self, $actions, $changed, $all) = @_;
    my $exceptionType = $all->{exception}->selectedType();
    if ($exceptionType eq 'exception_service') {
        my $services = $self->global()->modInstance('services');
        my $servEx = $all->{exception}->subtype();
        my $serviceId = $servEx->value();
        my @args = @{ $services->serviceIptablesArgs($serviceId) };
        foreach my $arg (@args) {
            if (not $arg) {
                throw EBox::Exceptions::External(
                    __x('Cannot add service {srv} because it will allow access to all connections',
                        srv => $servEx->printableValue())
                   );
            }
        }
    }

}

sub firewallRules
{
    my ($self, $chain) = @_;
    my $global = $self->global();
    my $objects = $global->modInstance('objects');
    my $services = $global->modInstance('services');
    my $captureHTTPRule;
    if ($chain eq 'captive') {
        # captive chain is in NAT/prerouting so we must capture traffic for http
        # proxy there
        my $squid = $global->modInstance('squid');
        if ($squid and $squid->transproxy()) {
            my $port = $squid->port();
            $captureHTTPRule =  " -p tcp --dport 80 -j REDIRECT --to-ports $port";
        }
    }

    my @rules;
    foreach my $id (@{ $self->enabledRows() }) {
        my $row = $self->row($id);
        my $exception = $row->elementByName('exception');
        my $selectedType = $exception->selectedType;
        if ($selectedType eq 'exception_object') {
            my $objectId = $exception->subtype()->value();
            my $members = $objects->objectMembers($objectId);

            if ($captureHTTPRule) {
                # must have priority over normal redirect rulex
                push @rules,  map {
                    $_ . ' ' . $captureHTTPRule
                } @{ $members->iptablesSrcParams(1) };
            }

            push @rules,  map {
                $_ . ' -j RETURN'
            } @{ $members->iptablesSrcParams(1) };

        } elsif ($selectedType eq 'exception_service') {
            my $serviceId = $exception->subtype()->value();
            # there are not capture http rules even if is a rule that refers to
            # port 80, like the proxy ignores fw service rules when in
            # transparent mode
            push @rules,  map {
                $_ . ' -j RETURN'
            } @{ $services->serviceIptablesArgs($serviceId) };
        } else {
            die "Bad selected type $selectedType";
        }
    }

    return \@rules;
}

sub _filterExceptionPrintableValue
{
    my ($type) = @_;

    my $selected = $type->selectedType();
    my $value = $type->printableValue();

    if ($selected eq 'exception_object') {
        return __x('Object: {o}', o => $value);
    } elsif ($selected eq 'exception_service') {
        return __x('Service: {s}', s => $value);
    } else {
        return $value;
    }
}

1;
