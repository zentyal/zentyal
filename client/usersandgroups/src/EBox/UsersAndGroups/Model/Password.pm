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

# Class: EBox::UsersAndGroups::Model::Password
#   
#   TODO: Document class
#

package EBox::UsersAndGroups::Model::Password;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::UsersAndGroups::Types::Password;
use EBox::UserCorner::Auth;

use Apache2::RequestUtil;
use File::Temp qw/tempfile/;

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
    return __('Password management');
}

sub _table
{

    my @tableHead = 
    ( 
        new EBox::UsersAndGroups::Types::Password(
            'fieldName' => 'pass1',
            'printableName' => __('New password'),
            'size' => '8',
            'unique' => 1,
            'editable' => 1
        ),
        new EBox::UsersAndGroups::Types::Password(
            'fieldName' => 'pass2',
            'printableName' => __('Re-type new password'),
            'size' => '8',
            'unique' => 1,
            'editable' => 1
        ),
    );
    my $dataTable = 
    { 
        'tableName' => 'Password',
        'printableTableName' => __('Password'),
        'modelDomain' => 'Users',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => '', # FIXME
    };

    return $dataTable;
}

sub _addTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;

    my $pass1 = $paramsRef->{'pass1'};
    my $pass2 = $paramsRef->{'pass2'};

    my $users = EBox::Global->modInstance('users');

    my $r = Apache2::RequestUtil->request;
    my $user = $r->user;

    if ($pass1->cmp($pass2) != 0) {
        throw EBox::Exceptions::External(__('Passwords do not match.'));
    }
    my $userinfo = { 'username' => $user, 'password' => $pass1->value() };
    $users->modifyUserLocal($userinfo);
    EBox::UserCorner::Auth->updatePassword($user,$pass1->value());

    my $slaves = $users->listSlaves();
    for my $slave (@{$slaves}) {
        my $journaldir = EBox::UserCorner::usercornerdir() . "userjournal/$slave";
        (-d $journaldir) or `mkdir -p $journaldir`;

        my ($fh, $filename) = tempfile("modifyUser-XXXX", DIR => $journaldir);
        print $fh "modifyUser\n";
        print $fh "$user\n";
        $fh->close();
        rename($filename, "$filename.pending");
        `chmod 644 $filename.pending`;
    }

    $self->setMessage(__('Password successfully updated'));
}

1;
