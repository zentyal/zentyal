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

# Class: EBox::SysInfo::Model::TimeZone
#
#   This model is used to configure the system time zone
#

package EBox::SysInfo::Model::TimeZone;

use strict;
use warnings;

use Error qw(:try);

use EBox::Gettext;
use EBox::Types::TimeZone;

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

    my @tableHead = (# TODO: The default value of the timezone is readed from /etc/timezone
                     new EBox::Types::TimeZone( fieldName => 'timezone',
                                                printableName => __('Time zone'),
                                                editable => 1,
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

# Method: formSubmitted
#
# Overrides:
#
#   <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self) = @_;

    #my $sysinfo = EBox::Global->modInstance('sysinfo');

    #$self->_requireParam('country', __('country'));
    #$self->_requireParam('continent', __('continent'));

    #my $continent = $self->param('continent');
    #my $country = $self->param('country');

    #$sysinfo->setNewTimeZone($continent, $country);

    #my $audit = EBox::Global->modInstance('audit');
    #$audit->logAction('System', 'General', 'changeTimezone', "$continent/$country");
}

1;
