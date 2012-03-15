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

# Class: EBox::SysInfo::Model::AdminPort
#
#   This model is used to configure the interface port
#

package EBox::SysInfo::Model::AdminPort;

use strict;
use warnings;

use Error qw(:try);

use EBox::Gettext;
use EBox::Types::Port;

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

    my @tableHead = (new EBox::Types::Port( fieldName      => 'port',
                                            printableValue => __('Port'),
                                            editable       => 1,
                                            defaultValue   => 443));

    my $dataTable =
    {
        'tableName' => 'AdminPort',
        'printableTableName' => __('Administration interface TCP port'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
        'help' => __('On this page you can set different general system settings'),
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

    #my $global = EBox::Global->getInstance();
    #my $apache = $global->modInstance('apache');

    #if (defined($self->param('setport'))) {
    #    my $port = $self->param('port');
    #    $apache->setPort($port);
    #    my $audit = EBox::Global->modInstance('audit');
    #    $audit->logAction('System', 'General', 'setAdminPort', $port);
    #}
}

1;
