# Copyright (C) 2010 eBox Technologies S. L.
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


package EBox::FTP::Model::Options;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Boolean;

# eBox exceptions used
use EBox::Exceptions::External;

sub new
{
    my $class = shift @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub populateAnonymous
{
    my @values = (
        {
          'value' => 'disabled',
          'printableValue' => __('Disabled'),
        },
        {
          'value' => 'readonly',
          'printableValue' => __('Read only'),
        },
        {
          'value' => 'write',
          'printableValue' => __('Read/Write'),
        },
    );

    return \@values;
}

sub _table
{
    my @tableDesc =
        (
         new EBox::Types::Select(
                fieldName => 'anonymous',
                printableName => __('Anonymous access'),
                populate => \&populateAnonymous,
                editable => 1,
                defaultValue => 'disabled',
                help => __('Sets the permissions for the /pub directory'),
               ),
         new EBox::Types::Boolean(
                fieldName => 'userHomes',
                printableName => __('Personal directories'),
                editable => 1,
                defaultValue => 1,
                help => __('Enable FTP access for each user to its /home directory'),
               ),
        );

    my $dataForm = {
                tableName          => 'Options',
                printableTableName => __('General configuration settings'),
                pageTitle          => __('FTP Server'),
                modelDomain        => 'FTP',
                defaultActions     => [ 'editField', 'changeView' ],
                tableDescription   => \@tableDesc,
                help               => __('Here you can set access permissions for the FTP server'),
    };

    return $dataForm;
}

sub anonymous
{
    my ($self) = @_;

    return $self->row()->valueByName('anonymous');
}

sub userHomes
{
    my ($self) = @_;

    return $self->row()->valueByName('userHomes');
}

1;
