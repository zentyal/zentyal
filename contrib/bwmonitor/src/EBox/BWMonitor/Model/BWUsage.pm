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

package EBox::BWMonitor::Model::BWUsage;

use base 'EBox::Model::DataTable';

# Class: EBox::BWMonitor::Model::BWUsage
#
#   Bandwidth usage from each IP for last hour
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HostIP::BCast;
use TryCatch::Lite;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    bless($self, $class);
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
       new EBox::Types::HostIP::BCast(
            fieldName     => 'ip',
            printableName => __('IP'),
            editable      => 0,
       ),
       new EBox::Types::Text(
            fieldName => 'extrecv',
            printableName => __('External in'),
            editable => 0,
       ),
       new EBox::Types::Text(
            fieldName => 'extsent',
            printableName => __('External out'),
            editable => 0,
       ),
       new EBox::Types::Text(
            fieldName => 'intrecv',
            printableName => __('Internal in'),
            editable => 0,
       ),
       new EBox::Types::Text(
            fieldName => 'intsent',
            printableName => __('Internal out'),
            editable => 0,
       ),
    );

    my $dataTable =
    {
        tableName          => 'BWUsage',
        printableTableName => __('Last hour bandwidth usage'),
        printableRowName   => __('client'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        noDataMsg          => __('There is no data to show yet, the values are updated every 10 minutes'),
        help               => __('Bandwidth usage for each connected client.'),
        modelDomain        => 'BWMonitor',
        withoutActions     => 1,
    };

    return $dataTable;
}

sub precondition
{
    return EBox::Global->modInstance('bwmonitor')->isEnabled();
}

sub preconditionFailMsg
{
    return __('Bandwidth Monitor must be enabled in order to get data.');
}

sub noDataMsg
{
    my ($self) = @_;

    unless (@{$self->parentModule->ifaces()}) {
        return __(q{Bandwidth Monitor is not configured to monitor any interface. You can enable interfaces in the 'Configure interfaces' tab});
    }
    return $self->SUPER::noDataMsg();
}

sub syncRows
{
    my ($self, $currentRows)  = @_;

    # empty table
    foreach my $id (@{$currentRows}) {
        $self->removeRow($id, 1);
    }

    my $module = EBox::Global->modInstance('bwmonitor');
    my $time = time() - 3600;

    my $clients = $module->allUsersExtBWUsage($time);

    my $error;
    foreach my $client (@{$clients}) {
        try {
            $self->add(ip => $client->{ip},
                   extrecv => $self->_format($client->{extrecv}),
                   extsent => $self->_format($client->{extsent}),
                   intrecv => $self->_format($client->{intrecv}),
                   intsent => $self->_format($client->{intsent}));
        } catch (EBox::Exceptions::InvalidData $e) {
            $error = "$e";
        }
    }

    if ($error) {
        my $message = __x('Error when extracting usage data: {err}', err => $error);
        $self->setMessage($message, 'error');
    }

    return 1;
}

# convert bytes to a readable string
sub _format
{
    my ($self, $bytes) = @_;
    my ($n, $units) = $self->_bytes($bytes);

    return '0' if ($n == 0);
    return "$bytes B" if ($units eq 'B');
    return sprintf("%.1f $units", $n);
}

sub _bytes
{
    my ($self, $bytes) = @_;
    return '0'            if ($bytes == 0);
    return ($bytes, 'B')  if ($bytes < 1024); $bytes = $bytes / 1024;
    return ($bytes, 'KB') if ($bytes < 1024); $bytes = $bytes / 1024;
    return ($bytes, 'MB') if ($bytes < 1024); $bytes = $bytes / 1024;
    return ($bytes, 'GB') if ($bytes < 1024);
}

1;
