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

# Class: EBox::LTSP::Model::ImageCreation
#
#   TODO: Document class
#

package EBox::LTSP::Model::ImageCreation;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Validate qw(:all);

use EBox::Types::Select;
use EBox::Types::Boolean;
use EBox::Types::Action;

use EBox::Exceptions::External;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _select_architectures
{
    return [
        {
            value => 'i386',
            printableValue => __('32 bits'),
        },
        {
            value => 'amd64',
            printableValue => __('64 bits'),
        },
    ];
}

sub _table
{
    my ($self) = @_;

    my @fields =
    (
        new EBox::Types::Select(
            'fieldName'     => 'architecture',
            'printableName' => __('Architecture'),
            'populate'      => \&_select_architectures,
            'editable'      => 1,
        ),
        new EBox::Types::Boolean(
            'fieldName'     => 'fat',
            'printableName' => __('Fat Image'),
            'dafaultValue'  => 0,
            'editable'      => 1,
        ),
    );

    my $customActions = [
        new EBox::Types::Action(
            name => 'create',
            printableValue => __('Create Image'),
            model => $self,
            handler => \&_doCreate,
            message => __('Creating image. This process will be shown in the '
                          . 'dashboard widget until it finishes.'),
        ),
    ];

    my $form =
    {
        'tableName' => 'ImageCreation',
        'modelDomain' => 'LTSP',
        'printableTableName' => __('Image Creation'),
        'defaultActions' => [],
        'tableDescription' => \@fields,
        'customActions' => $customActions,
    };
    return $form;
}

sub _doCreate
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

    my $arch = $params{'architecture'};

    # Needed here because the code in the script takes some seconds to execute
    $ltsp->st_set_string('arch', $arch);
    $ltsp->st_set_string('work', 'build');
    if (fork() == 0) {
        EBox::Sudo::root('/usr/share/zentyal-ltsp/build-image ' . $arch);
        exit(0);
    }
    $self->setMessage($action->message(), 'note');
    $self->{customActions} = {};
}

1;
