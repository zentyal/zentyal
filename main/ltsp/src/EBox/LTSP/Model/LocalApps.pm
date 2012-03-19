# Copyright (C)
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

package EBox::LTSP::Model::LocalApps;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Validate qw(:all);

use EBox::Types::Text;
use EBox::Types::Action;

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
            'help' => 'Enter the applications separated by spaces',
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

    my $applications = $params{'applications'};

    if ( $applications eq '' ) {
        throw EBox::Exceptions::External(
            __('The list must contain at least one application.')
        );
    }

    my $arch = $self->parentRow()->valueByName('architecture');
    EBox::info("\$applications=$applications \$arch=$arch");

    # Needed here because the code in the script takes some seconds to execute
    $ltsp->st_set_string('arch', $arch);
    $ltsp->st_set_string('work', 'install');
    if (fork() == 0) {
        EBox::Sudo::root('/usr/share/zentyal-ltsp/install-local-applications '
                         . $arch . " \"$applications\"");
        exit(0);
    }
    $self->setMessage($action->message(), 'note');
    $self->{customActions} = {};
}

1;
