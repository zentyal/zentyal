# Copyright (C) 2010-2014 Zentyal S.L.
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

# Class: EBox::Samba::Model::PAM
#

use strict;
use warnings;

package EBox::Samba::Model::SambaSettings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Boolean;

# Group: Public methods

# Constructor: new
#
#      Create the PAM settings form
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
#       Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{
    my ($self) = @_;
    my $users = $self->parentModule();
    my @tableDesc = (
        new EBox::Types::Boolean(
            fieldName => 'enable_full_audit',
            printableName => __('Enable full_audit'),
            defaultValue => 0,
            editable => 1,
            help => __('Enable the full_audit vfs object (record Samba VFS operations in the system log)')
        ),
    );

    my $dataForm = {
        tableName           => 'SambaSettings',
        printableTableName  => __('Samba settings'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Samba',
    };

    return $dataForm;
}

# Method: precondition
#
#   Check if usersandgroups is enabled.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $ed = EBox::Global->communityEdition();
    my $dep = $self->parentModule()->isEnabled();

    # Return false if this is a community edition
    if ($ed) {
        return 0;
    }

    if (! $dep) {
        return 0;
    }

    return 1;
}

# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail
#
# Overrides:
#
#       <EBox::Model::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;
    
    my $ed = EBox::Global->communityEdition();
    my $dep = $self->parentModule()->isEnabled();

    if ($ed) {
        return __sx("This GUI feature is just available for {oh}Commercial Zentyal Server Edition{ch} if you don't update your Zentyal version, you need to use it from CLI.", oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>')
    }

    if (! $dep) {
        return __('You must enable the Users and Groups module to access the LDAP information.');
    }
}

1;