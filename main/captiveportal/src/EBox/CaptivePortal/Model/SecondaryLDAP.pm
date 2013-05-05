# Copyright (C) 2011-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::CaptivePortal::Model::SecondaryLDAP;

# Class: EBox::CaptivePortal::Model::SecondaryLDAP;

use base 'EBox::Model::DataForm';
#
#   Form to configure a secondary LDAP to login into captive portal
#

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Text;

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
            new EBox::Types::Boolean(
                fieldName     => 'enabled',
                printableName => __('Use secondary LDAP'),
                editable      => 1,
                defaultValue  => 0,
                ),
            new EBox::Types::Text(
                fieldName     => 'url',
                printableName => __('LDAP URL'),
                editable      => 1,
                size          => 30,
                allowUnsafeChars => 1,
                defaultValue  => 'ldaps://domain.com',
                ),

            new EBox::Types::Text(
                fieldName     => 'binddn',
                printableName => __('Bind DN'),
                help          => __x('Bind DN pattern. {x} will be replaced with the username', x => '{USERNAME}'),
                editable      => 1,
                size          => 30,
                allowUnsafeChars => 1,
                defaultValue  => 'uid={USERNAME},ou=Users,dc=domain,dc=com',
                ),
            );

    my $dataTable =
    {
        tableName          => 'SecondaryLDAP',
        printableTableName => __('Secondary LDAP'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('Here you can configure a secondary LDAP. If login fails as Zentyal user this LDAP will be used.'),
        modelDomain        => 'CaptivePortal',
    };

    return $dataTable;
}

1;
