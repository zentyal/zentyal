# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::Samba::Model::SambaShares
#
#  This model is used to configure shares different to those which are
#  given by the group share
#
package EBox::Samba::Model::SambaShares;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Config;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Global;
use EBox::Model::Manager;
use EBox::Samba::Group;
use EBox::Samba::SecurityPrincipal;
use EBox::Samba::SmbClient;
use EBox::Sudo;
use EBox::Types::Boolean;
use EBox::Types::HasMany;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Validate;

use Cwd 'abs_path';
use Error qw(:try);
use Samba::Security::AccessControlEntry;
use Samba::Security::Descriptor qw(
    DOMAIN_RID_ADMINISTRATOR
    SEC_ACE_FLAG_CONTAINER_INHERIT
    SEC_ACE_FLAG_OBJECT_INHERIT
    SEC_ACE_TYPE_ACCESS_ALLOWED
    SEC_FILE_EXECUTE
    SEC_RIGHTS_FILE_ALL
    SEC_RIGHTS_FILE_READ
    SEC_RIGHTS_FILE_WRITE
    SEC_STD_ALL
    SEC_STD_DELETE
    SECINFO_DACL
    SECINFO_GROUP
    SECINFO_OWNER
    SECINFO_PROTECTED_DACL
);
use String::ShellQuote 'shell_quote';

use constant FILTER_PATH => ('/bin', '/boot', '/dev', '/etc', '/lib', '/root',
                             '/proc', '/run', '/sbin', '/sys', '/var', '/usr');

# Constructor: new
#
#     Create the new Samba shares table
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Samba::Model::SambaShares> - the newly created object
#     instance
#
sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);
    bless ($self, $class);

    return $self;
}

# Method: updatedRowNotify
#
#      Notify cloud-prof if installed to be restarted
#
# Overrides:
#
#      <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    if ($row->isEqualTo($oldRow)) {
        # no need to notify changes
        return;
    }

    my $global = EBox::Global->getInstance();
    if ( $global->modExists('cloud-prof') ) {
        $global->modChange('cloud-prof');
    }
}

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc = (
       new EBox::Types::Boolean(
                               fieldName     => 'sync',
                               printableName => __('Sync with Zentyal Cloud'),
                               editable      => 1,
                               defaultValue  => 0,
                               help          => __('Files will be synchronized with Zentyal Cloud.'),
                               hidden        => \&_hideSyncOption,
                               ),
       new EBox::Types::Text(
                               fieldName     => 'share',
                               printableName => __('Share name'),
                               editable      => 1,
                               unique        => 1,
                              ),
       new EBox::Types::Union(
                               fieldName => 'path',
                               printableName => __('Share path'),
                               subtypes =>
                                [
                                     new EBox::Types::Text(
                                       fieldName     => 'zentyal',
                                       printableName =>
                                            __('Directory under Zentyal'),
                                       editable      => 1,
                                       unique        => 1,
                                                        ),
                                     new EBox::Types::Text(
                                       fieldName     => 'system',
                                       printableName => __('File system path'),
                                       editable      => 1,
                                       unique        => 1,
                                                          ),
                               ],
                               help => _pathHelp($self->parentModule()->SHARES_DIR())),
       new EBox::Types::Text(
                               fieldName     => 'comment',
                               printableName => __('Comment'),
                               editable      => 1,
                              ),
       new EBox::Types::Boolean(
                                   fieldName     => 'guest',
                                   printableName => __('Guest access'),
                                   editable      => 1,
                                   defaultValue  => 0,
                                   help          => __('This share will not require authentication.'),
                                   ),
       new EBox::Types::HasMany(
                               fieldName     => 'access',
                               printableName => __('Access control'),
                               foreignModel => 'SambaSharePermissions',
                               view => '/Samba/View/SambaSharePermissions'
                              ),
       # This hidden field is filled with the group name when the share is configured as
       # a group share through the group addon
       new EBox::Types::Text(
            fieldName => 'groupShare',
            hidden => 1,
            optional => 1,
            ),
      );

    my $dataTable = {
                     tableName          => 'SambaShares',
                     printableTableName => __('Shares'),
                     modelDomain        => 'Samba',
                     defaultActions     => [ 'add', 'del',
                                             'editField', 'changeView' ],
                     tableDescription   => \@tableDesc,
                     menuNamespace      => 'Samba/View/SambaShares',
                     class              => 'dataTable',
                     help               => _sharesHelp(),
                     printableRowName   => __('share'),
                     enableProperty     => 1,
                     defaultEnabledValue => 1,
                     orderedBy          => 'share',
                    };

      return $dataTable;
}

# Method: validateTypedRow
#
#       Override <EBox::Model::DataTable::validateTypedRow> method
#
#   Check if the share path is allowed or not
sub validateTypedRow
{
    my ($self, $action, $parms)  = @_;

    return unless ($action eq 'add' or $action eq 'update');

    if (exists $parms->{'path'}) {
        my $path = $parms->{'path'}->selectedType();
        if ($path eq 'system') {
            # Check if it is an allowed system path
            my $normalized = abs_path($parms->{'path'}->value());
            if ($normalized eq '/') {
                throw EBox::Exceptions::External(__('The file system root directory cannot be used as share'));
            }
            foreach my $filterPath (FILTER_PATH) {
                if ($normalized =~ /^$filterPath/) {
                    throw EBox::Exceptions::External(
                            __x('Path not allowed. It cannot be under {dir}',
                                dir => $normalized
                               )
                    );
                }
            }
            EBox::Validate::checkAbsoluteFilePath($parms->{'path'}->value(),
                                           __('Samba share absolute path')
                                                );
        } else {
            # Check if it is a valid directory
            my $dir = $parms->{'path'}->value();
            EBox::Validate::checkFilePath($dir, __('Samba share directory'));
        }
    }
}

# Method: removeRow
#
#   Override <EBox::Model::DataTable::removeRow> method
#
#   Overriden to warn the user if the directory is not empty
#
sub removeRow
{
    my ($self, $id, $force) = @_;

    my $row = $self->row($id);

    if ($force or $row->elementByName('path')->selectedType() eq 'system') {
        return $self->SUPER::removeRow($id, $force);
    }

    my $path =  $self->parentModule()->SHARES_DIR() . '/' .
                $row->valueByName('path');
    unless ( -d $path) {
        return $self->SUPER::removeRow($id, $force);
    }

    opendir (my $dir, $path);
    while(my $entry = readdir ($dir)) {
        next if($entry =~ /^\.\.?$/);
        closedir ($dir);
        throw EBox::Exceptions::DataInUse(
         __('The directory is not empty. Are you sure you want to remove it?'));
    }
    closedir($dir);

    return $self->SUPER::removeRow($id, $force);
}

# Method: deletedRowNotify
#
#   Override <EBox::Model::DataTable::validateRow> method
#
#   Write down shares directories to be removed when saving changes
#
sub deletedRowNotify
{
    my ($self, $row) = @_;

    my $path = $row->elementByName('path');

    # We are only interested in shares created under /home/samba/shares
    return unless ($path->selectedType() eq 'zentyal');

    my $mgr = EBox::Model::Manager->instance();
    my $deletedModel = $mgr->model('SambaDeletedShares');
    $deletedModel->addRow('path' => $path->value());
}

# Method: createDirs
#
#   This method is used to create the necessary directories for those
#   shares which must live under /home/samba/shares
#
sub createDirs
{
    my ($self, $recursive) = @_;

    for my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $enabled     = $row->valueByName('enabled');
        my $shareName   = $row->valueByName('share');
        my $pathType    = $row->elementByName('path');
        my $guestAccess = $row->valueByName('guest');

        next unless ($enabled);
        next if ($shareName eq 'test-windows');

        my $path = undef;
        if ($pathType->selectedType() eq 'zentyal') {
            $path = $self->parentModule()->SHARES_DIR() . '/' . $pathType->value();
        } elsif ($pathType->selectedType() eq 'system') {
            $path = $pathType->value();
        } else {
            EBox::error("Unknown share type on share '$shareName'");
        }
        next unless defined $path;

        # Don't do anything if the directory already exists and the option to manage ACLs
        # only from Windows is set
        next if (EBox::Config::boolean('unmanaged_acls') and EBox::Sudo::fileTest('-d', $path));

        my $sambaMod = EBox::Global->modInstance('samba');
        my $domainSID = $sambaMod->ldb()->domainSID();
        my $domainAdminSID = "$domainSID-500";
        my $builtinAdministratorsSID = 'S-1-5-32-544';
        my $systemSID = "S-1-5-18";
        my @cmds = ();
        push (@cmds, "mkdir -p '$path'");
        push (@cmds, "chmod 0770 '$path'");
        EBox::Sudo::root(@cmds);

        my $host = $sambaMod->ldb()->rootDse()->get_value('dnsHostName');
        unless (defined $host and length $host) {
            throw EBox::Exceptions::Internal('Could not get DNS hostname');
        }
        my $smb = new EBox::Samba::SmbClient(target => $host, service => $shareName, RID => DOMAIN_RID_ADMINISTRATOR);
        my $sd = new Samba::Security::Descriptor();
        # Set the owner and the group. We differ here from Windows because they just set the owner to
        # builtin/Administrators but this other setting should be compatible and better looking when using Linux
        # console.
        $sd->owner($domainAdminSID);
        $sd->group($builtinAdministratorsSID);

        my $readRights = SEC_FILE_EXECUTE | SEC_RIGHTS_FILE_READ;
        my $writeRights = SEC_RIGHTS_FILE_WRITE | SEC_STD_DELETE;
        my $adminRights = SEC_STD_ALL | SEC_RIGHTS_FILE_ALL;
        my $defaultInheritance = SEC_ACE_FLAG_CONTAINER_INHERIT | SEC_ACE_FLAG_OBJECT_INHERIT;
        # Always, full control to Builtin/Administrators group, Users/Administrator and System users.
        my @superAdminSIDs = ($builtinAdministratorsSID, $domainAdminSID, $systemSID);

        for my $superAdminSID (@superAdminSIDs) {
            my $ace = new Samba::Security::AccessControlEntry(
                $superAdminSID, SEC_ACE_TYPE_ACCESS_ALLOWED, $adminRights, $defaultInheritance);
            $sd->dacl_add($ace);
        }

        if ($guestAccess) {
            my $domainSID = $sambaMod->ldb->domainSID();
            my $domainGuestsSID = "$domainSID-514";
            my $ace = new Samba::Security::AccessControlEntry(
                $domainGuestsSID, SEC_ACE_TYPE_ACCESS_ALLOWED, $readRights | $writeRights, $defaultInheritance);
            $sd->dacl_add($ace);
        } else {
            for my $subId (@{$row->subModel('access')->ids()}) {
                my $subRow = $row->subModel('access')->row($subId);
                my $permissions = $subRow->elementByName('permissions');

                my $userType = $subRow->elementByName('user_group');
                my $account = $userType->printableValue();
                my $qobject = shell_quote($account);

                my $object = new EBox::Samba::SecurityPrincipal(samAccountName => $account);
                unless ($object->exists()) {
                    next;
                }

                my $sid = $object->sid();
                my $rights = undef;
                if ($permissions->value() eq 'readOnly') {
                    $rights = $readRights;
                } elsif ($permissions->value() eq 'readWrite') {
                    $rights = $readRights | $writeRights;
                } elsif ($permissions->value() eq 'administrator') {
                    $rights = $adminRights;
                } else {
                    my $type = $permissions->value();
                    EBox::error("Unknown share permission type '$type'");
                    next;
                }
                my $ace = new Samba::Security::AccessControlEntry(
                    $sid, SEC_ACE_TYPE_ACCESS_ALLOWED, $rights, $defaultInheritance);
                $sd->dacl_add($ace);
            }
        }
        my $relativeSharePath = '/';
        # type                     : 0x9c04 (39940)
        # 0: SEC_DESC_OWNER_DEFAULTED
        # 0: SEC_DESC_GROUP_DEFAULTED
        # 1: SEC_DESC_DACL_PRESENT
        # 0: SEC_DESC_DACL_DEFAULTED
        # 0: SEC_DESC_SACL_PRESENT
        # 0: SEC_DESC_SACL_DEFAULTED
        # 0: SEC_DESC_DACL_TRUSTED
        # 0: SEC_DESC_SERVER_SECURITY
        # 0: SEC_DESC_DACL_AUTO_INHERIT_REQ
        # 0: SEC_DESC_SACL_AUTO_INHERIT_REQ
        # 1: SEC_DESC_DACL_AUTO_INHERITED
        # 1: SEC_DESC_SACL_AUTO_INHERITED
        # 1: SEC_DESC_DACL_PROTECTED
        # 0: SEC_DESC_SACL_PROTECTED
        # 0: SEC_DESC_RM_CONTROL_VALID
        # 1: SEC_DESC_SELF_RELATIVE
        my $sinfo = SECINFO_OWNER | SECINFO_GROUP | SECINFO_DACL | SECINFO_PROTECTED_DACL;
        $smb->set_sd($relativeSharePath, $sd, $sinfo);
    }
}

# Private methods

sub _hideSyncOption
{
    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        return (not $rs->filesSyncAvailable() or _syncAllShares());
    }

    return 1;
}

sub _syncAllShares
{
    my $samba = EBox::Global->modInstance('samba');
    return $samba->model('SyncShares')->syncValue();
}

sub _pathHelp
{
    my ($sharesPath) = @_;

    return __x( '{openit}Directory under Zentyal{closeit} will ' .
            'automatically create the share.' .
            "directory in {sharesPath} {br}" .
            '{openit}File system path{closeit} will allow you to share '.
            'an existing directory within your file system',
               sharesPath => $sharesPath,
               openit  => '<i>',
               closeit => '</i>',
               br      => '<br>');

}

sub _sharesHelp
{
    return __('Here you can create shares with more fine-grained permission ' .
              'control. ' .
              'You can use an existing directory or pick a name and let Zentyal ' .
              'create it for you.');
}

# Method: headTile
#
#   Overrides <EBox::Model::DataTable::headTitle>
#
#
sub headTitle
{
    return undef;
}

1;
