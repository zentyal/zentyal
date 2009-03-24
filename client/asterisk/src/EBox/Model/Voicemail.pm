# Copyright  
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


# Class: EBox::Asterisk::Model::Voicemail
#   
#

package EBox::Asterisk::Model::Voicemail;

use EBox::Gettext;
use EBox::UsersAndGroups::Types::Password;
use EBox::UserCorner::Auth;
use Apache2::RequestUtil;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

sub new 
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

sub pageTitle
{
    return __('Voicemail password management');
}

sub _table
{

    my @tableHead = 
    ( 
        new EBox::UsersAndGroups::Types::Password(
            'fieldName' => 'pass',
            'printableName' => __('New password'),
            'size' => '4',
            'unique' => 1,
            'editable' => 1
        ),
    );
    my $dataTable = 
    { 
        'tableName' => 'Voicemail',
        'printableTableName' => __('Voicemail'),
        'modelDomain' => 'Asterisk',
        'defaultActions' => ['editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => '', # FIXME
    };

    return $dataTable;
}

sub _addTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;

    my $pass = $paramsRef->{'pass'};

    my $users = EBox::Global->modInstance('users');

    my $ldap = EBox::Ldap->instance();

    my $r = Apache2::RequestUtil->request;
    my $user = $r->user;

    my $dn = "uid=" . $user . "," . $users->usersDn;

    my %attrs = (
        'AstAccountVMPassword' => $pass->value(),
    );

    $ldap->modify($dn, { replace => \%attrs });

    $self->setMessage(__('Password successfully updated'));
}

1;
