# Copyright (C) 2008 eBox Technologies S.L.
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

# Class: EBox::EGroupware::Model::Applications
#
#   TODO: Document class
#

package EBox::EGroupware::Model::Applications;

use EBox::Gettext;
use EBox::Validate qw(:all);
use Error qw(:try);

use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Config;
use EBox::Sudo;
use EBox::Exceptions::External;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

use constant APPS => (
                      'admin',
                      'preferences',
                      'home',
                      'notifywindow',
                      'emailadmin',
                      'etemplate',
                      'filemanager',
                      'news_admin',
                      'phpbrain',
                      'polls',
                      'registration',
#                      'sambaadmin',
                      'workflow',
                      'addressbook',
                      'calendar',
                      'felamimail',
                      'infolog',
                      'projectmanager',
                      'resources',
#                      'sitemgr',
                      'timesheet',
                      'wiki',
#                      'sitemgr-link',
                      'manual'
                     );

sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows)  = @_;

    unless (@{$currentRows}) {
        # if there are no rows, we have to add them
        foreach my $app (APPS) {
            $self->add(app => $app, enabled => $app ne 'admin');
        }
        return 1;
    } else {
        return 0;
    }
}

sub _table
{

    my @tableHead =
    (
        new EBox::Types::Text(
            'fieldName' => 'app',
            'printableName' => __('Application'),
            'unique' => 1,
            'editable' => 0,
        ),
        new EBox::Types::Boolean(
            'fieldName' => 'enabled',
            'printableName' => __('Enabled'),
            'editable' => 1,
        ),
    );
    my $dataTable =
    {
        'tableName' => 'Applications',
        'printableTableName' => __('Applications'),
        'printableRowName' => __('application'),
        'modelDomain' => 'EGroupware',
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

1;
