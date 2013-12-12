# Copyright (C) 2011-2011 Zentyal S.L.
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

package EBox::CaptivePortal::Model::Settings;

# Class: EBox::CaptivePortal::Model::Settings
#
#   Form to set the Captive Portal general settings.
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Port;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    bless ($self, $class);
    return $self;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
        new EBox::Types::Select(
            fieldName     => 'group',
            printableName => __('Group'),
            populate      => \&populateGroups,
            editable      => 1,
            disableCache  => 1,
            help          => __('Only users in this group will be allowed to login.'),
            ),
       new EBox::Types::Port(
           fieldName     => 'http_port',
           printableName => __('HTTP port'),
           editable      => 1,
           defaultValue  => 4444,
           ),
        new EBox::Types::Port(
           fieldName     => 'https_port',
           printableName => __('HTTPS port'),
           editable      => 1,
           defaultValue  => 4443,
           ),
      );

    my $dataTable =
    {
        tableName          => 'Settings',
        printableTableName => __('General Settings'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('Here you can define general settings for captive portal.'),
        modelDomain        => 'CaptivePortal',
    };

    return $dataTable;
}


sub populateGroups
{
    my $userMod = EBox::Global->modInstance('users');
    my @groups = (
        {
            value          => '__all__',
            printableValue => __('All users'),
        }
    );
    push (@groups, map (
            {
               value            => $_->{account},
               printableValue   => $_->{account},
            }, $userMod->groups()
         )
    );
    return \@groups;
}



# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (exists $params_r->{http_port} or exists $params_r->{https_port}) {
        # Check ports (different and available)
        my $http_port = exists $params_r->{http_port} ?
                               $params_r->{http_port}->value() :
                               $actual_r->{http_port}->value();

        my $https_port = exists $params_r->{https_port} ?
                                $params_r->{https_port}->value() :
                                $actual_r->{https_port}->value();

        if ($http_port eq $https_port) {
            throw EBox::Exceptions::External(__('HTTP and HTTPS ports should be different'));
        }

        my $oldHttp = $self->http_portValue();
        my $oldHttps = $self->https_portValue();

        # Available?
        $self->_checkPortAvailable($http_port) unless ($oldHttp eq $http_port);
        $self->_checkPortAvailable($https_port) unless ($oldHttps eq $https_port);
    }
}

sub _checkPortAvailable
{
    my ($self, $port) = @_;

    my $firewall = EBox::Global->modInstance('firewall');
    if (not $firewall->availablePort('tcp', $port )) {
        throw EBox::Exceptions::External(
            __x('{port} is already in use. Please choose another', port => $port)
        );
    }
}



1;
