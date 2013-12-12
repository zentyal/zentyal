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

    my $fs = EBox::Config::configkey('samba_fs');
    my $s3fs = (defined $fs and $fs eq 's3fs');

    my $avModuleEnabled = 0;
    if (EBox::Global->modExists('antivirus')) {
        my $avModule = EBox::Global->modInstance('antivirus');
        $avModuleEnabled = $avModule->isEnabled();
    }

    return ($s3fs and $avModuleEnabled);
}

sub preconditionFailMsg
{
    my ($self) = @_;

    my $fs = EBox::Config::configkey('samba_fs');
    my $s3fs = (defined $fs and $fs eq 's3fs');

    return __("You are using the new samba 'ntvfs' file server, " .
              "which is incompatible with vfs plugins such the " .
              "antivirus. If you wish to enable this feature, add " .
              "the Zentyal PPA to your APT sources.list and install " .
              "our samba4 package, then change the samba config key " .
              "'samba_fs' to 's3fs' in /etc/zentyal/samba.conf") unless $s3fs;

    return __("Zentyal antivirus module must be installed and enabled to use this feature");
}

1;
