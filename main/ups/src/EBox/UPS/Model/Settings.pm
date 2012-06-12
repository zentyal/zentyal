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

package EBox::UPS::Model::Settings;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;

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
        new EBox::Types::Boolean(
                fieldName => 'userHomes',
                printableName => __('Personal directories'),
                editable => 1,
                defaultValue => 1,
                #help => __('Enable authenticated FTP access to each user home directory.'),
               ),
        new EBox::Types::Boolean(
                fieldName => 'chrootUsers',
                printableName => __('Restrict to personal directories'),
                editable => 1,
                defaultValue => 1,
                #help => __('Restrict access to each user home directory. Take into account that this restriction can be circumvented under some conditions.'),
               ),
    );

    my $dataForm = {
        tableName          => 'Settings',
        printableTableName => __('General configuration settings'),
        pageTitle          => __('FTP Server'),
        modelDomain        => 'UPS',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        help               => __('foo'),
    };

    return $dataForm;
}

1;
