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
#      Form to change the user Voicemail settings in the UserCorner
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Password;
use EBox::Types::MailAddress;
use EBox::Types::Boolean;
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
    return __('Voicemail settings');
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
        new EBox::Types::Password(
            fieldName     => 'pass',
            printableName => __('New password'),
            size          => '4',
            unique        => 1,
            editable      => 1
        ),
        new EBox::Types::MailAddress(
            fieldName     => 'mail',
            printableName => __('Mail address'),
            size          => '14',
            unique        => 1,
            editable      => 1
        ),
        new EBox::Types::Boolean(
            fieldName     => 'attach',
            printableName => __('Attach messages'),
            editable      => 1,
            defaultValue  => 0,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'delete',
            printableName => __('Delete sent messages'),
            editable      => 1,
            defaultValue  => 0,
        ),
    );
    my $dataTable =
    {
        tableName          => 'Voicemail',
        printableTableName => __('Voicemail settings'),
        defaultActions     => ['editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => 'Change your Voicemail settings',
        modelDomain        => 'Asterisk',
    };

    return $dataTable;
}


# FIXME doc
sub _addTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;

    my $pass = $paramsRef->{'pass'}->value();
    my $mail = $paramsRef->{'mail'}->value();
    my $attach = if ($paramsRef->{'attach'}->value()) ? 'yes' : 'no';
    my $delete = if ($paramsRef->{'delete'}->value()) ? 'yes' : 'no';

    my $users = EBox::Global->modInstance('users');

    my $ldap = EBox::Ldap->instance();

    my $r = Apache2::RequestUtil->request;
    my $user = $r->user;

    my $dn = "uid=" . $user . "," . $users->usersDn;

    my %attrs = (
        'AstAccountVMPassword' => $pass,
        'AstAccountVMMail' => $mail,
        'AstAccountVMAttach' => $attach,
        'AstAccountVMDelete' => $delete,
    );

    $ldap->modify($dn, { replace => \%attrs });

    $self->setMessage(__('Settings successfully updated'));
}

1;
