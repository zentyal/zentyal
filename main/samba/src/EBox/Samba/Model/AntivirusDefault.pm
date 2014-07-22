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

# Class: EBox::Samba::Model::AntivirusDefault
#
#   TODO: Document class
#

use strict;
use warnings;

package EBox::Samba::Model::AntivirusDefault;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Port;

use base 'EBox::Model::DataForm';

# This is the socket where the scannedonly VFS plugin will send the files to scan.
# The zavsd daemon listen on that socket and act as a multithreaded proxy for clamd
use constant ZAVS_SOCKET    => '/var/lib/zentyal/zavs';
use constant QUARANTINE_DIR => '/var/lib/zentyal/quarantine';

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
    my @tableHead = (
        new EBox::Types::Boolean(
            'fieldName'     => 'scan',
            'printableName' => __('Enable virus scanning'),
            'editable'      => 1,
            'defaultValue'  => 0,
        ),
    );

    my $dataTable = {
        'tableName'          => 'AntivirusDefault',
        'printableTableName' => __('Antivirus default settings'),
        'pageTitle'          => undef,
        'modelDomain'        => 'Samba',
        'defaultActions'     => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription'   => \@tableHead,
        'help' => '', # FIXME
    };

    return $dataTable;
}

sub precondition
{
    my ($self) = @_;

    my $avModule = EBox::Global->modInstance('antivirus');
    return (defined ($avModule) and $avModule->isEnabled());
}

sub preconditionFailMsg
{
    my ($self) = @_;

    return __("Zentyal antivirus module must be installed and enabled to use this feature");
}

1;
