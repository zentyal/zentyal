# Copyright (C) 2009 eBox Technologies S.L.
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

# Class: EBox::UsersAndGroups::Model::Mode
#
# This class contains the options needed to enable the usersandgroups module.

package EBox::UsersAndGroups::Model::Mode;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Host;
use EBox::Types::Port;
use EBox::Types::Password;
use EBox::View::Customizer;
use EBox::Config;

use strict;
use warnings;

# eBox uses

# Group: Public methods

# Constructor: new
#
#      Create a data form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless( $self, $class );

    return $self;
}

# Method: _table
#
#	Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{

    my ($self) = @_;

    my @tableDesc = (
        new EBox::Types::Select (
            fieldName => 'mode',
            printableName => __('Mode'),
            options => [
                { 'value' => 'master', 'printableValue' => __('Master') },
                { 'value' => 'slave', 'printableValue' => __('Slave') },
                { 'value' => 'ad-slave', 'printableValue' => __('Windows AD Slave') },
            ],
            editable => 1,
            defaultValue => 'master',
        ),
        new EBox::Types::Text (
            fieldName => 'dn',
            printableName => __('LDAP DN'),
            editable => 1,
            allowUnsafeChars => 1,
            size => 36,
            defaultValue => _dnFromHostname(),
            help => __('Only for master and AD slave configuration')
        ),
        new EBox::Types::Host (
            fieldName => 'remote',
            printableName => __('Master host'),
            editable => 1,
            help => __('Only for slave configuration: IP of the master eBox or Windows AD')
        ),
        new EBox::Types::Password (
            fieldName => 'password',
            printableName => __('LDAP password'),
            editable => 1,
            help => __('Master eBox LDAP password')
        ),
    );

    my $dataForm = {
        tableName           => 'Mode',
        printableTableName  => __('Configuration'),
        pageTitle           => __('eBox Users Mode'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Users',
    };

    return $dataForm;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to implement
#   a custom behaviour to enable and disable the 'remote' field
#   depending on the 'mode' value
#
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    # Be careful: password should be always the first item if there are more
    # as we remove it using shift later
    my @enableMaster = ('dn');
    my @disableMaster = ('password', 'remote');
    my @enableSlave = ('password', 'remote');
    my @disableSlave = ('dn');
    my @enableAD = ('dn', 'remote');
    my @disableAD = ('password');

    $customizer->setOnChangeActions(
            { mode =>
                {
                  'master'   => {
                        enable  => \@enableMaster,
                        disable => \@disableMaster,
                    },
                  'slave'    => {
                        enable  => \@enableSlave,
                        disable => \@disableSlave,
                    },
                  'ad-slave' => {
                        enable  => \@enableAD,
                        disable => \@disableAD,
                    },
                }
            });
    return $customizer;
}

sub _dnFromHostname
{
    my $hostname = `hostname -f`;
    chomp($hostname);
    my $dn = join(',', map("dc=$_", split(/\./, $hostname)));
    return $dn;
}

1;
