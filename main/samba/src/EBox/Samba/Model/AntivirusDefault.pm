# Copyright (C) 2012 eBox Technologies S.L.
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
            'printableName' => __('Scan'),
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

    my $global = EBox::Global->getInstance();
    my $hasLibs = ($global->modExists('antivirus') and
           ((-f '/usr/lib/i386-linux-gnu/samba/vfs/vscan-clamav.so') or
            (-f '/usr/lib/x86_64-linux-gnu/samba/vfs/vscan-clamav.so')));

    my $fs = EBox::Config::configkey('samba-fs');
    my $s3fs = (defined $fs and $fs eq 's3fs');

    return ($hasLibs and $s3fs);
}

sub preconditionFailMsg
{
    my ($self) = @_;

    my $fs = EBox::Config::configkey('samba-fs');
    my $ntvfs = (defined $fs and $fs eq 'ntvfs');

    my $msg =  __('In order to enable virus scanning on the shares you ' .
                  'have to install and enable the antivirus module.');

    if ($ntvfs) {
        $msg = __("You are using the new samba 'ntvfs' file server, " .
                  "which is incompatible with vfs plugins such the " .
                  "antivirus. If you wish to enable this feature, add " .
                  "the Zentyal PPA to your APT sources.list and install " .
                  "our samba4 package, then change the samba config key " .
                  "'samba_fs' to 's3fs' in /etc/zentyal/samba.conf");
    }

    return $msg;
}

1;
