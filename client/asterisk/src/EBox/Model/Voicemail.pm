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


package EBox::Asterisk::Model::Voicemail;

# Class: EBox::Asterisk::Model::Voicemail
#
#      Form to change the user Voicemail password in the UserCorner
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::UsersAndGroups::Types::Password;
use Apache2::RequestUtil;


# Group: Public methods

# Constructor: new
#
#       Create the new Voicemail model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::Voicemail> - the recently created model
#
sub new
{
   my $class = shift;

   my $self = $class->SUPER::new(@_);

   bless($self, $class);

   return $self;
}

# Method: pageTitle
#
#      Get the i18ned name of the page where the model is contained, if any
#
# Overrides:
#
#      <EBox::Model::DataForm::pageTitle>
#
# Returns:
#
#      string
#
sub pageTitle
{
    return __('Voicemail password management');
}


# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{

    my @tableHeader =
    (
        new EBox::UsersAndGroups::Types::Password(
            fieldName     => 'pass',
            printableName => __('New password'),
            size          => '4',
            unique        => 1,
            editable      => 1
        ),
    );
    my $dataTable =
    {
        tableName          => 'Voicemail',
        printableTableName => __('Voicemail password management'),
        defaultActions     => ['editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => 'Change your Voicemail password',
        modelDomain        => 'Asterisk',
    };

    return $dataTable;
}


# FIXME doc
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
