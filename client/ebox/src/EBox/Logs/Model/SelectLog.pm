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

package EBox::Logs::Model::SelectLog;
use base 'EBox::Model::DataTable';
#

use strict;
use warnings;

use Error qw(:try);
use EBox::Global;
use EBox::Gettext;
use EBox::Logs::Consolidate;

sub new 
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub rows
{
    my ($self, @p) = @_;

    $self->refreshRows();

    return $self->SUPER::rows(@p);
}

sub refreshRows
{
    my ($self) = @_;

    my $global  = EBox::Global->getInstance();
    my $modName = $self->{gconfmodule}->name();
    
    my $alreadyChanged = $global->modIsChanged($modName);

    try {
        $self->removeAll(1);
        
        my @mods = @{ $global->modInstancesOfType('EBox::LogObserver') };
        foreach my $mod (@mods) {
            foreach my $urlGroup (@{ $mod->reportUrls }) {
                $self->addRow( @{ $urlGroup } )
            }
        }

    }
   finally {
       if (not $alreadyChanged) {
           # unmark module as changed
           $global->modRestarted($modName);
       }
   };

}


sub logRows
{
    my ($self) = @_;

}

# Function: filterDomain
#
#   This is a callback used to filter the output of the field domain.
#   It basically translates the log domain
#
# Parameters:
#
#   instancedType-  an object derivated of <EBox::Types::Abastract>
#
# Return:
#
#   string - translation
sub filterDomain
{
    my ($instancedType) = @_;

    my $logs = EBox::Global->modInstance('logs');

    my $table = $logs->getTableInfo($instancedType->value());

    my $translation = $table->{'name'};

    if ($translation) {
        return $translation;
    } else {
        return $instancedType->value();
    }
}



sub _table
{
    my @tableHead =
        (
         new EBox::Types::Text(
                    'fieldName' => 'domain',
                    'printableName' => __('Domain'),
                    'size' => '12',
                    'unique' => 0,
                    'editable' => 0,
                    'filter' => \&filterDomain
                              ),
         new EBox::Types::Link(
                               fieldName => 'raw',
                               printableName => __('Full report'),
                               editable      => 0,
                               optional      => 1,
                              ),
         new EBox::Types::Link(
                               fieldName => 'summary',
                               printableName => __('Summarized report'),
                               editable      => 0,
                               optional      => 1,
                              ),

        );

    my $dataTable = 
        { 
            'tableName' => 'SelectLog',
#            'printableTableName' => undef,
            'pageTitle' => __('Select report'),
            'defaultController' => '/ebox/Logs/Controller/SelectLog',
            'defaultActions' => [ 'editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'order' => 0,
             'rowUnique' => 0,
            'printableRowName' => __('logs'),
             'messages'         => {
                                    add => undef,
                                   },
        };

    return $dataTable;
}

sub Viewer
{
    return '/ajax/tableBodyWithoutActions.mas';
}


1;
