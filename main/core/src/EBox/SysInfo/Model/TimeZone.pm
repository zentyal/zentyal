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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Class: EBox::SysInfo::Model::TimeZone
#
#   This model is used to configure the system time zone
#
use strict;
use warnings;

package EBox::SysInfo::Model::TimeZone;
use base 'EBox::Model::DataForm';

use TryCatch;
use File::Slurp;

use EBox::Gettext;
use EBox::Types::TimeZone;
use DateTime::TimeZone;

use constant TZ_FILE => '/etc/timezone';

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

    my @tableHead = (new EBox::Types::TimeZone( fieldName    => 'timezone',
                                                editable     => 1,
                                                defaultValue => \&_getTimezone,
                                                help =>  __('You will probably have to restart some services after ' .
                                                            'changing the time zone.')));

    my $dataTable =
    {
        'tableName' => 'TimeZone',
        'printableTableName' => __('Time zone'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

sub _getTimezone
{
    my $tz;
    try {
        $tz = read_file(TZ_FILE);
        chomp $tz;

        my %links = DateTime::TimeZone->links;
        if ((exists $links{$tz}) and $links{$tz}) {
            my $newZone =  $links{$tz};
            if ($newZone eq 'UTC') {
                return 'Etc/UTC';
            }
            return $newZone;
        }
    } catch {
        $tz = undef;
    }

    if (not $tz) {
        $tz = 'Etc/UTC';
    }

    return $tz;
}

1;
