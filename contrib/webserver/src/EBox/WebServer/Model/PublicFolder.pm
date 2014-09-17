# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::WebServer::Model::PublicFolder;
use base 'EBox::Model::DataForm';

# Class: EBox::WebServer::Model::PublicFolder
#
#   Form to set the user public folder settings for the web server.
#

use EBox::Global;
use EBox::Gettext;

use EBox::Types::Port;
use EBox::Types::Boolean;
use EBox::Types::Union;
use EBox::Types::Union::Text;

use EBox::Validate;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;

use TryCatch::Lite;

use constant PUBLIC_DIR => 'public_html';

# Group: Public methods

# Constructor: new
#
#       Create the new PublicFolder model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::WebServer::Model::PublicFolder> - the recently
#       created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: validateTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::ValidateTypedRow>
#
# Exceptions:
#
#       <EBox::Exceptions::DataExists> - if the port number is already
#       in use by any ebox module.
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $oldFields) = @_;

    if (exists $changedFields->{enableDir} and
        $changedFields->{enableDir}->value())  {
        my $users = EBox::Global->modInstance('samba');
        if (not $users) {
            throw EBox::Exceptions::External(
                __('Having installed and configured the Users and Groups module is required to allow HTML directories for users.')
            );
        }
        my $configured = $users->configured();
        if (not $configured) {
            throw EBox::Exceptions::External(
                __('A properly configured Users and Groups module is required to allow HTML directories for users. To configure it, please enable it at least one time.')
            );
        }
    }
}

# Group: Public class static methods

# Method: DefaultEnableDir
#
#     Accessor to the default value for the enableDir field in the
#     model.
#
# Returns:
#
#     boolean - the default value for enableDir field.
#
sub DefaultEnableDir
{
    return 0;
}

# Method: message
#
#   Allows us to introduce some conditionals when showing the message
#
# Overrides:
#
#       <EBox::Model::DataTable::message>
#
#
sub message
{
    my ($self, $action) = @_;
    if ($action and ($action eq 'update')) {
        my $userstatus = $self->value('enableDir');
        if ($userstatus)  {
            return __('User public folder configuration settings updated.') . '<br>' .
                   __x('Remember that in order to have UserDir working, you should create the {p} directory, and to provide www-data execution permissions over the involved /home/user directories.', p => PUBLIC_DIR);
        }
    }

    return $self->SUPER::message($action);
}

# Group: Protected methods

# Method: _table
#
#       The table description which consists of:
#
#       enabledDir  - <EBox::Types::Boolean>
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{

    my @tableHeader = (
        new EBox::Types::Boolean(
            fieldName     => 'enableDir',
            printableName => __x('Enable per user {dirName}', dirName => PUBLIC_DIR),
            editable      => 1,
            defaultValue  => EBox::WebServer::Model::PublicFolder::DefaultEnableDir(),
            help          => __('Allow users to publish web documents using the public_html directory on their home.')
            ),
    );

    my $dataTable = {
       tableName          => 'PublicFolder',
       printableTableName => __('User public folder settings'),
       defaultActions     => [ 'editField', 'changeView' ],
       tableDescription   => \@tableHeader,
       class              => 'dataForm',
       help               => __x('User public folder configuration. If you enable '
                                 . 'user to publish their own html pages, those should be '
                                 . 'loaded from {dirName} directory from their home directories.',
                                 dirName => PUBLIC_DIR),
       messages           => {
                              update => __('User public folder configuration settings updated.'),
                             },
       modelDomain        => 'WebServer',
    };

    return $dataTable;
}

1;
