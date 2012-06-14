# Copyright (C) 2012 eBox Technologies S. L.
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

package EBox::NUT::Model::Mode;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Select;

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub _table
{
    my @tableDesc = (
        new EBox::Types::Select(
            fieldName => 'mode',
            printableName => __('Mode'),
            defaultValue => 'standalone',
            populate => \&_mode,
            editable => 1,
            help => __(''),
        ),
    );

    my $dataForm = {
        tableName          => 'Mode',
        printableTableName => __('Mode'),
        modelDomain        => 'NUT',
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        help               => __(''), # FIXME
    };

    return $dataForm;
}

sub _mode
{
    return [
        { value => 'standalone', printableValue => __('Standalone') },
        { value => 'server',     printableValue => __('Server') },
        { value => 'client',     printableValue => __('Client') },
    ];
}

1;
