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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::LTSP::Model::LocalApps
#
#   TODO: Document class
#

use strict;
use warnings;

package EBox::LTSP::Model::LocalApps;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Validate qw(:all);

use EBox::Types::Text;
use EBox::Types::Action;

use EBox::Exceptions::Internal;
use EBox::WebAdmin;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my @fields =
    (
        new EBox::Types::Text(
            'fieldName' => 'applications',
            'printableName' => __('Applications'),
            'size' => '15',
            'editable' => 1,
            'help' => __('Enter the applications separated by spaces'),
        ),
    );

    my $customActions = [
        new EBox::Types::Action(
            name => 'install',
            printableValue => __('Install Application'),
            model => $self,
            handler => \&_doInstall,
            message => __('Installing application into image. This process will '
                          . 'be shown in the dashboard widget until it finishes.'),
        ),
    ];

    my $dataTable =
    {
        'tableName' => 'LocalApps',
        'printableTableName' => __('Local Applications'),
        'printableRowName' => __('Application'),
        'modelDomain' => 'LTSP',
        'defaultActions' => [],
        'tableDescription' => \@fields,
        'customActions' => $customActions,
    };

    return $dataTable;
}

sub _doInstall
{
    my ($self, $action, $id, %params) = @_;

    my $ltsp = EBox::Global->modInstance('ltsp');
    my $work = $ltsp->st_get_string('work');

    if ( (defined $work) and ($work ne 'none')) {
        throw EBox::Exceptions::External(
            __('There is a job already in progress with some image. '
               . 'Please, wait until it is finished.')
        );
    }

    my $name         = $self->parentRow()->valueByName('name');
    my $applications = $params{'applications'};

    if ( $applications eq '' ) {
        throw EBox::Exceptions::External(
            __('The list must contain at least one application.')
        );
    }

    my $pid = fork();
    unless (defined $pid) {
        throw EBox::Exceptions::Internal("Cannot fork().");
    }

    if ($pid == 0) {
        # Needed here because the code in the script takes some seconds to execute
        $ltsp->st_set_string('work', 'install');

        EBox::WebAdmin::cleanupForExec();
        exec('sudo /usr/share/zentyal-ltsp/install-local-applications '
             . "$name \"$applications\"");
    }
    $self->setMessage($action->message(), 'note');
    $self->{customActions} = {};
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to
#   provide a custom HTML title with breadcrumbs
#
sub viewCustomizer
{
    my ($self) = @_;

    my $row  = $self->parentRow();
    my $name = $row->valueByName('name');
    my $arch = $row->printableValueByName('architecture');
    my $fat  = $row->valueByName('fat');

    my $title = "$name: $arch";

    if ($fat) {
        $title .= __(' (Fat Image)');
    }

    my $custom =  $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([
        {
            title => $title,
            link  => '/LTSP/Composite/Composite#ClientImages',
        },
        {
            title => $self->printableName(),
            link  => ''
        }
    ]);

    return $custom;
}

1;
