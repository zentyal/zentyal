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

package EBox::CaptivePortal::Model::BWSettings;

use base 'EBox::Model::DataForm';

# Class: EBox::CaptivePortal::Model::BWSettings
#
#   Form to set the Captive Portal bwmonitor related settings
#

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Boolean;
use EBox::Types::Int;
use EBox::Types::Select;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    bless ($self, $class);
    return $self;
}

sub _bwModEnabled
{
    return 0 unless (EBox::Global->modExists('bwmonitor'));
    return EBox::Global->modInstance('bwmonitor')->isEnabled();
}

sub precondition
{
    return _bwModEnabled;
}

sub preconditionFailMsg
{
    unless (EBox::Global->modExists('bwmonitor')) {
        return __('If you want to limit bandwidth usage install and enable Bandwidth Monitor module.');
    }

    # Not enabled:
    return __x('If you want to limit bandwidth usage enable Bandwidth Monitor in {begina}Module Status{enda} section.', begina => '<a href="/ServiceModule/StatusView">', enda => '</a>');
}

sub limitBWValue
{
    my ($self) = @_;
    if (not $self->_bwModEnabled()) {
        return 0;
    }

    return $self->row()->valueByName('limitBW');
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

    my @tableHeader;
    push (@tableHeader,
            new EBox::Types::Boolean(
                fieldName     => 'limitBW',
                printableName => __('Limit bandwidth usage'),
                defaultValue  => 0,
                editable      => 1,
                ),

            new EBox::Types::Int(
                fieldName     => 'defaultQuota',
                printableName => __('Bandwidth quota'),
                trailingText  => __('MB'),
                help          => __('Maximum bandwidth usage for defined period. 0 means no limit.'),
                defaultValue  => 0,
                editable      => 1,
                size          => 7,
                )
         );

    my @options = (
        {
            value => 'day',
            printableValue => __('Day')
        },
        {
            value => 'week',
            printableValue => __('Week')
        },
        {
            value => 'month',
            printableValue => __('Month'),
        }
    );

    push (@tableHeader,
           new EBox::Types::Select(
               fieldName => 'defaultQuotaPeriod',
               printableName => __('Period'),
               editable => 1,
               options  => \@options,
               defaultValue => 'month',
               ));

    my $dataTable =
    {
        tableName          => 'BWSettings',
        printableTableName => __('Bandwidth Settings'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('Here you can setup bandwidth usage quota for captive portal users.'),
        modelDomain        => 'CaptivePortal',
    };

    return $dataTable;
}

# reimplement this with model changed notifier when it works again
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    if ($row->valueByName('limitBW')) {
        my $interfaces = $self->parentModule()->model('Interfaces');
        my $anySync = $interfaces->bwMonitorEnabled();
        if ($anySync) {
            $self->setMessage(
                __('All the enabled interfaces have been also enabled in bandwith monitor module')
               );
        }
    }
}

1;
