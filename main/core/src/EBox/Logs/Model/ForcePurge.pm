# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::Logs::Model::ForcePurge
#
#       Form model to purge a selected kind of log from a fixed
#       date. This model inherits from <EBox::Model::DataForm::Action>
#       since no data is required to be stored.
#

use strict;
use warnings;

package EBox::Logs::Model::ForcePurge;

use base 'EBox::Model::DataForm::Action';

use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Select;

# Core modules
use TryCatch;

# Group: Public methods

# Constructor: new
#
#      Create a force purge form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
# Returns:
#
#      <EBox::Logs::Model::ForcePurge> - the recently created model
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);
    bless( $self, $class );

    return $self;
}

# Method: formSubmitted
#
# Overrides:
#
#      <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self, $row, $force) = @_;

    my $lifeTime = $row->valueByName('lifeTime');

    my $logs = EBox::Global->modInstance('logs');
    $logs->forcePurge($lifeTime);
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
        new EBox::Types::Select(
                                'fieldName' => 'lifeTime',
                                'printableName' => __('Purge logs older than'),
                                populate       => \&_populateSelectLifeTime,
                                editable       => 1,
                                defaultValue   => 1,
                               ),
       );

    my $dataForm = {
                     tableName           => 'ForcePurge',
                     printableTableName  => __('Force log purge'),
                     modelDomain         => 'Logs',
                     defaultActions      => [ 'editField', 'changeView' ],
                     printableActionName => __('Purge'),
                     tableDescription    => \@tableDesc,
                     class               => 'dataForm',
                    };

    return $dataForm;
}

sub _populateSelectLifeTime
{
    # life time values must be in hours
    return  [
           {
            printableValue => __('one hour'),
            value          => 1,
           },
           {
            printableValue => __('twelve hours'),
            value          => 12,
           },
           {
            printableValue => __('one day'),
            value          => 24,
           },
           {
            printableValue => __('three days'),
            value          => 72,
           },
           {
            printableValue => __('one week'),
            value          =>  168,
           },
           {
            printableValue => __('fifteeen days'),
            value          =>  360,
           },
           {
            printableValue => __('thirty days'),
            value          =>  720,
           },
           {
            printableValue => __('ninety days'),
            value          =>  2160,
           },
    ];
}

1;
