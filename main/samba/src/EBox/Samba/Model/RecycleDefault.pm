# Copyright (C) 2009-2012 Zentyal S.L.
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

# Class: EBox::Samba::Model::RecycleDefault
#
#   TODO: Document class
#

package EBox::Samba::Model::RecycleDefault;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Port;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

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

    my @tableHead =
    (
        new EBox::Types::Boolean(
            'fieldName' => 'enabled',
            'printableName' => __('Enable recycle bin'),
            'editable' => 1,
            'defaultValue' => 0
        ),
    );
    my $dataTable =
    {
        'tableName' => 'RecycleDefault',
        'printableTableName' => __('Recycle Bin default settings'),
        'modelDomain' => 'Samba',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => 'If Recycle Bin is enabled on a share, the deleted files on the share are stored on it instead of being deleted forever. This is the default setting that can be overrided by adding exceptions.',
        'pageTitle' => undef,
    };

    return $dataTable;
}

sub precondition
{
    my ($self) = @_;

    my $fs = EBox::Config::configkey('samba_fs');
    my $s3fs = (defined $fs and $fs eq 's3fs');

    return ($s3fs);
}

sub preconditionFailMsg
{
    my ($self) = @_;

    return __("You are using the new samba 'ntvfs' file server, " .
              "which is incompatible with vfs plugins such the " .
              "recycle bin. If you wish to enable this feature, add " .
              "the Zentyal PPA to your APT sources.list and install " .
              "our samba4 package, then change the samba config key " .
              "'samba_fs' to 's3fs' in /etc/zentyal/samba.conf");
}
1;
