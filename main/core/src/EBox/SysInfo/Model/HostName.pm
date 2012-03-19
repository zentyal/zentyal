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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Class: EBox::SysInfo::Model::HostName
#
#   This model is used to configure the host name and domain
#

package EBox::SysInfo::Model::HostName;

use strict;
use warnings;

use Error qw(:try);

use EBox::Gettext;
use EBox::Types::DomainName;
use EBox::Types::Host;

use base 'EBox::Model::DataForm';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Host( fieldName     => 'hostname',
                                            printableName => __('Host name'),
                                            defaultValue  => \&_getHostname,
                                            editable      => 1),

                     new EBox::Types::DomainName( fieldName     => 'hostdomain',
                                                  printableName => __('Host domain'),
                                                  defaultValue  => \&_getHostdomain,
                                                  editable      => 1,
                                                  help          => __('You will need to restart all the services or reboot the system to apply the hostname change.')));

    my $dataTable =
    {
        'tableName' => 'HostName',
        'printableTableName' => __('Host name and domain'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

sub _getHostname
{
    my $hostname = `hostname`;
    return $hostname;
}

sub _getHostdomain
{
    my $hostdomain = `hostname -d`;
    unless ($hostdomain) {
        $hostdomain = 'zentyal.lan';
    }
    return $hostdomain;
}

1;
