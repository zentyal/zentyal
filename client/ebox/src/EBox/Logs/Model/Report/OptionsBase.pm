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

package EBox::Logs::Model::Report::OptionsBase;
use base qw(EBox::Model::DataForm);

use strict;
use warnings;

use EBox::Gettext;
use Error qw(:try);

sub periods
{
    my ($package) = @_;
    return [qw(hourly daily weekly monthly)];
}


sub defaultPeriod
{
    my ($package) = @_;
    return 'daily';
}


my %printableValues = (
                       hourly => __('hour'),
                       daily  => __('day'),
                       weekly => __('week'),
                       monthly => __('month'),
                      );

sub populateSelect
{
    my ($package) = @_;
    my @options;


    my @periods = @{ $package->periods() };

    foreach my $period (@periods) {
        push @options, {
                        value => $period,
                        printableValue => $printableValues{$period},
                       }
    }

    return \@options;
}

# Method: _standardTablehead
#
#    this return a standard table head. Appropiate for models with only the time
#    period option
sub _standardTablehead
{
    my ($package) = @_;
    my $populateSelect = sub { 
        return $package->populateSelect()
    };

    my $tableHead = [

                     new EBox::Types::Select(
                                             fieldName => 'timePeriod',
                                             printableName => __('Report time period'),
                                             editable => 1,
                                             populate => $populateSelect,
                                             defaultValue => $package->defaultPeriod(),
                                            )
                    ];
}


#  Method: _table
#
#  This implementation of the _table method would be suffice for most cases.
#  It depends in the calues supplied by the methods modelDomain, tableName and _standardTablehead
sub _table
{
    my ($package) = @_;
    
    my $tableHead = $package->_standardTablehead();
     
    my $dataTable = 
        { 
            'tableName' => $package->tableName(),
            'printableTableName' => __('Report options'),
            'defaultActions' => [ 'changeView', 'editField' ],
            'tableDescription' => $tableHead,
#            'class' => 'dataTable',
            'order' => 0,
#            'help' => __x('Enable/disable logging per-module basis'),
            'rowUnique' => 0,
             'modelDomain' => $package->modelDomain(),
            'messages'     => $package->_messages(),
        };

    return $dataTable;
}

# Method: modelDomain
#
#  Abstract method
#  Must return the model domain
sub modelDomain
{
    throw EBox::Exceptions::NotImplemented('modelDomain');
}


sub setTypedRow
{
    my ($self, @params) = @_;

    my $global  = EBox::Global->getInstance();
    my $modName = $self->{gconfmodule}->name();
    
    my $alreadyChanged = $global->modIsChanged($modName);

    try {
        $self->SUPER::setTypedRow(@params);
    }
    finally {
       if (not $alreadyChanged) {
           # unmark module as changed
           $global->modRestarted($modName);
       }
    };

}

sub _messages
{
    my ($package) = @_;

    return {
            'add'       => undef,
            'del'       => undef,
            'update'    => undef,
            'moveUp'    => undef,
            'moveDown'  => undef,
           };
}

# Method: reportUrl
#
#   Abstract method.
#   This must be the URL of the report page. The user will be redirected there
#   when the options will be setted
sub reportUrl
{
    throw EBox::Exceptions::NotImplemented('reportUIrl');
}

sub formSubmitted
{
    my ($self) = @_;
    $self->pushRedirection($self->reportUrl);
}



1;
