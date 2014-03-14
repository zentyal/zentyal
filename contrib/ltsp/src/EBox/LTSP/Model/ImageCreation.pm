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

# Class: EBox::LTSP::Model::ImageCreation
#
#   TODO: Document class
#

use strict;
use warnings;

package EBox::LTSP::Model::ImageCreation;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Validate qw(:all);

use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::Boolean;
use EBox::Types::Action;

use EBox::Exceptions::External;
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
        new EBox::Types::Text(
            'fieldName'     => 'name',
            'printableName' => __('Name'),
            'size'          => '20',
            'editable'      => 1,
            'help' => __('Name that will be used to identify the image.'),
        ),
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
    my $state = $ltsp->get_state();
    my $work = $state->{work};

    if ( (defined $work) and ($work ne 'none')) {
        throw EBox::Exceptions::External(
            __('There is a job already in progress with some image. '
               . 'Please, wait until it is finished.')
        );
    }

    my $name = $params{'name'};
    my $arch = $params{'architecture'};
    my $fat  = ($params{'fat'} ? 1 : 0);

    unless (EBox::Validate::checkName($name)) {
        throw EBox::Exceptions::External(
            __('Incorrect name.')
        );
    }

    # Check we are not overwriting an already existing image
    if (exists $state->{images}->{$name}) {
        throw EBox::Exceptions::External(__('The image already exists.'));
    }

    my $pid = fork();
    unless (defined $pid) {
        throw EBox::Exceptions::Internal("Cannot fork().");
    }

    if ($pid == 0) {
        # Needed here because the code in the script takes some seconds to execute
        $state->{work} = 'build';
        $state->{images}->{$name} = {state => 'build',
                                     arch  => $arch,
                                     fat   => $fat};
        $ltsp->set_state($state);

        EBox::WebAdmin::cleanupForExec();
        exec("sudo /usr/share/zentyal-ltsp/build-image $name $arch $fat");
    }
    $self->setMessage($action->message(), 'note');
    #$self->{customActions} = {};
}

1;
