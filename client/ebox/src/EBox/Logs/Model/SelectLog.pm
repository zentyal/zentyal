# Copyright (C) 2008-2010 eBox Technologies S.L.
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

use constant STORE_URL => 'http://store.zentyal.com/';
use constant UTM       => '?utm_source=zentyal&utm_medium=query.logs&utm_campaign=reports';
use constant PROF_URL  => STORE_URL . 'serversubscriptions/subscription-professional.html' . UTM;
use constant ENTER_URL => STORE_URL . 'serversubscriptions/subscription-enterprise.html' . UTM;
use constant REPORT_URL => 'http://www.zentyal.com/sample-report-pdf' . UTM;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: ids
#
#   Override <EBox::Model::DataTable::ids> as we don't need to
#   store these rows. Actually, the rows returned by this model
#   are built in runtime. All their elements are read only so
#   there is no need to store anything.
#
#   We simply create an id array using an integer for every
#   row.
#
#   This id will be used to build the row in runtime in
#   <EBox::Model::SelectLog::row)
sub ids
{
    my ($self) = @_;

    my @ids;
    my $logs = EBox::Global->modInstance('logs');
    my @mods = @{ $logs->getLogsModules() };
    my $idx = 0;
    foreach my $mod (@mods) {
        foreach my $urlGroup (@{ $mod->reportUrls }) {
            push (@ids, $idx);
            $idx++;
        }
    }
    return \@ids;
}

# Method: row
#
#   Override <EBox::Model::DataTable::row> as we don't need to
#   store these rows. Actually, the rows returned by this model
#   are built in runtime. All their elements are read only so
#   there is no need to store anything.
#
#   Use one of the id returned by <EBox::Model::SelectLog::ids>
#   to build and return the requested row

sub row
{
    my ($self, $id) = @_;

    my $logs = EBox::Global->modInstance('logs');
    my @mods = @{ $logs->getLogsModules() };
    my $idx = 0;
    my $rowValues;
    foreach my $mod (@mods) {
        foreach my $urlGroup (@{ $mod->reportUrls }) {
            if ($idx == $id) {
                my $row = $self->_setValueRow(%{$urlGroup});
                $row->setId($id);
                $row->setReadOnly(1);
                return $row;
            }
            $idx++;
        }
    }
    return undef;
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

# Method: viewCustomizer
#
#      Return a custom view customizer to set a permanent message
#      if needed
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    my $subscriptionLevel = -1;

    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $subscriptionLevel = $rs->subscriptionLevel();
    }
    unless ($subscriptionLevel > 0) {
        $customizer->setPermanentMessage($self->_commercialMsg());
    }

    return $customizer;
}

# Return the commercial message
sub _commercialMsg
{
    return __sx('Gain full access to frequent reports based on these logs by purchasing a '
                . '{openhrefp}Professional{closehref} or '
                . '{openhrefe}Enterprise Server Subscription{closehref}. '
                . 'You can see a sample of these reports '
                . '{openhrefr}here{closehref}.',
                openhrefp => '<a href="' . PROF_URL . '" target="_blank">',
                openhrefe => '<a href="' . ENTER_URL . '" target="_blank">',
                openhrefr => '<a href="' . REPORT_URL . '" target="_blank">',
                closehref => '</a>');
}


1;
