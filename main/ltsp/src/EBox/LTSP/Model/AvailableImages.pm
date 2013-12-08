# Copyright (C) 2012-2012 Zentyal S.L.
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

# Class: EBox::LTSP::Model::AvailableImages
#
#   TODO: Document class
#

package EBox::LTSP::Model::AvailableImages;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Validate qw(:all);

use EBox::Types::Select;
use EBox::Types::Boolean;
use EBox::Types::Action;
use EBox::Types::HasMany;

use EBox::Exceptions::Internal;
use EBox::Apache;
use EBox::Sudo;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: populate_architecture
#
#   Callback function to fill out the values that can
#   be picked from the <EBox::Types::Select> field architecture
#
# Returns:
#
#   Array ref of hash refs containing:
#
sub populate_architecture
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
            'fieldName' => 'architecture',
            'printableName' => __('Architecture'),
            'populate' => \&populate_architecture,
            'editable' => 0,
        ),

        new EBox::Types::Boolean(
            'fieldName' => 'fat',
            'printableName' => __('Fat Image'),
            'editable' => 0,
        ),
        new EBox::Types::HasMany(
            'fieldName' => 'applications',
            'printableName' => __('Local Applications'),
            'foreignModel' => 'ltsp/LocalApps',
            'view' => '/LTSP/View/LocalApps',
        ),
    );

    my $customActions = [
        new EBox::Types::Action(
            name => 'update',
            printableValue => __('Update Image'),
            model => $self,
            handler => \&_doUpdate,
            message => __('Updating image. This process will be shown in the '
                          . 'dashboard widget until it finishes.'),
            image => '/data/images/reload.png',
        ),
        new EBox::Types::Action(
            name => 'remove',
            printableValue => __('Remove Image'),
            model => $self,
            handler => \&_doRemove,
            message => __('The image and its configuration have been removed.'),
            image => '/data/images/delete.gif',
        ),
    ];

    my $dataTable =
    {
        'tableName' => 'AvailableImages',
        'printableTableName' => __('Available Images'),
        'printableRowName' => __('Image'),
        'modelDomain' => 'LTSP',
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@fields,
        'customActions' => $customActions,
        'help' => __('Images already created.'),
        'onlyCustomActions' => 1,
    };

    return $dataTable;
}

sub _doUpdate
{
    my ($self, $action, $id, %params) = @_;

    my $ltsp = $self->parentModule();
    my $work = $ltsp->st_get_string('work');

    if ((defined $work) and ($work ne 'none')) {
        throw EBox::Exceptions::External(
            __('There is a job already in progress with some image. '
               . 'Please, wait until it is finished.')
        );
    }

    my $arch = $self->row($id)->valueByName('architecture');
    my $fat  = ($self->row($id)->valueByName('fat') ? 1 : 0);

    my $pid = fork();
    unless (defined $pid) {
        throw EBox::Exceptions::Internal("Cannot fork().");
    }

    if ($pid == 0) {
        # Needed here because the code in the script takes some seconds to execute
        $ltsp->st_set_string('work', 'update');

        EBox::Apache::cleanupForExec();
        exec("sudo /usr/share/zentyal-ltsp/update-image $arch $fat");
    }
    $self->setMessage($action->message(), 'note');
    $self->{customActions} = {};
}

sub _doRemove
{
    my ($self, $action, $id, %params) = @_;

    my $ltsp = $self->parentModule();
    my $work = $ltsp->st_get_string('work');

    if ((defined $work) and ($work ne 'none')) {
        throw EBox::Exceptions::External(
            __('There is a job already in progress with some image. '
               . 'Please, wait until it is finished.')
        );
    }

    my $arch = $self->row($id)->valueByName('architecture');
    my $fat  = ($self->row($id)->valueByName('fat') ? 1 : 0);

    my $name;
    if ($fat) {
        $name = "fat-$arch";
    } else {
        $name = $arch;
    }

    # TODO: Use constants
    EBox::Sudo::root("rm -r /opt/ltsp/$name >> /var/log/zentyal/ltsp.log");
    EBox::Sudo::root("rm /opt/ltsp/images/$name.img >> /var/log/zentyal/ltsp.log");
    EBox::Sudo::root("rm -r /var/lib/tftpboot/ltsp/$name >> /var/log/zentyal/ltsp.log");

    $self->setMessage($action->message(), 'note');
    $self->{customActions} = {};
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#   to pre-add module rows.
sub syncRows
{
    my ($self, $currentRows)  = @_;

    my $rval = 0;
    my %rows;
    my $architecture;

    foreach my $id (@{$currentRows}) {
        $architecture = $self->row($id)->valueByName('architecture');
        if ($self->row($id)->valueByName('fat')) {
            if (not -f "/opt/ltsp/images/fat-$architecture.img") {
                # Image removal
                $self->removeRow($id);
                $rval = 1;
            } else {
                $rows{"fat-$architecture"} = 1;
            }
        } else {
            if (not -f "/opt/ltsp/images/$architecture.img") {
                # Image removal
                $self->removeRow($id);
                $rval = 1;
            } else {
                $rows{$architecture} = 1;
            }
            $rows{$architecture} = 1;
        }
    }

    # New images
    for my $arch (('i386', 'amd64')) {
        if ((-f "/opt/ltsp/images/$arch.img") and
            (not defined $rows{$arch}) ) {
            $self->add(architecture => $arch, fat => 0);
            $rval = 1;
        }
        if ((-f "/opt/ltsp/images/fat-$arch.img") and
            (not defined $rows{"fat-$arch"}) ) {
            $self->add(architecture => $arch, fat => 1);
            $rval = 1;
        }
    }

    return $rval;
}

1;
