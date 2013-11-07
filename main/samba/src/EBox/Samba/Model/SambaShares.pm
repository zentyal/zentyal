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
use EBox::Gettext;
use EBox::Global;
use EBox::Model::Manager;
use EBox::Sudo;
use EBox::Types::Boolean;
use EBox::Types::HasMany;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Validate;

use Sys::Filesystem;
use File::Basename qw( dirname );
use Cwd 'abs_path';
use Error qw(:try);

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

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $tableDesc = [
        new EBox::Types::Boolean(
            fieldName     => 'sync',
            printableName => __('Sync with Zentyal Cloud'),
            editable      => 1,
            defaultValue  => 0,
            help          => __('Files will be synchronized with Zentyal Cloud.'),
            hidden        => \&_hideSyncOption),
        new EBox::Types::Text(
            fieldName     => 'share',
            printableName => __('Share name'),
            editable      => 1,
            unique        => 1),
        new EBox::Types::Union(
            fieldName => 'path',
            printableName => __('Share path'),
            subtypes => [
                new EBox::Types::Text(
                    fieldName     => 'zentyal',
                    printableName => __('Directory under Zentyal'),
                    editable      => 1,
                    unique        => 1),
                new EBox::Types::Text(
                    fieldName     => 'system',
                    printableName => __('File system path'),
                    editable      => 1,
                    unique        => 1),
            ],
            help => _pathHelp($self->parentModule()->SHARES_DIR())),
        new EBox::Types::Text(
            fieldName     => 'comment',
            printableName => __('Comment'),
            editable      => 1),
        new EBox::Types::Boolean(
            fieldName     => 'guest',
            printableName => __('Guest access'),
            editable      => 1,
            defaultValue  => 0,
            help          => __('This share will not require authentication.')),
        new EBox::Types::Boolean(
            fieldName     => 'recursive_acls',
            printableName => __('Apply ACLs recursively'),
            editable      => 1,
            defaultValue  => 1,
            help          => __('ACL changes replace all permissions on subfolders of this share.')),
        new EBox::Types::HasMany(
            fieldName     => 'access',
            printableName => __('Access control'),
            foreignModel => 'SambaSharePermissions',
            view => '/Samba/View/SambaSharePermissions'),
        # This hidden field is filled with the group name when the share is configured as
        # a group share through the group addon
        new EBox::Types::Text(
            fieldName => 'groupShare',
            hidden => 1,
            optional => 1),
    ];

    my $dataTable = {
        tableName          => 'SambaShares',
        printableTableName => __('Shares'),
        modelDomain        => 'Samba',
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => $tableDesc,
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


# Method: tagShareRightsReset
#
#   Tag the given SambaShares' row as requiring to get the permissions applied on the file system.
#
#   Parameters:
#
#       row - The SambaShares row to tag.
#
sub tagShareRightsReset
{
    my ($self, $row) = @_;

    my $enabled     = $row->valueByName('enabled');
    my $shareName   = $row->valueByName('share');
    my $pathType    = $row->elementByName('path');

    if ($enabled) {
        my $path = undef;
        if ($pathType->selectedType() eq 'zentyal') {
            $path = $self->parentModule()->SHARES_DIR() . '/' . $pathType->value();
        } elsif ($pathType->selectedType() eq 'system') {
            $path = $pathType->value();
        } else {
            EBox::error("Unknown share type on share '$shareName'");
        }
        unless (defined $path) {
            return;
        }

        # Don't do anything if the directory already exists and the option to manage ACLs
        # only from Windows is set
        if (EBox::Config::boolean('unmanaged_acls') and EBox::Sudo::fileTest('-d', $path)) {
            return;
        }

        EBox::info("Tagging share '$shareName' as requiring a permission reset");
        # Store in redis that we should set acls, given the permission changed.
        my $sambaMod = EBox::Global->modInstance('samba');
        my $state = $sambaMod->get_state();
        unless (defined $state->{shares_set_rights}) {
            $state->{shares_set_rights} = {};
        }
        $state->{shares_set_rights}->{$shareName} = 1;
        $sambaMod->set_state($state);
    }
}

# Method: addedRowNotify
#
# Overrides:
#
#      <EBox::Model::DataTable::addedRowNotify>
#
sub addedRowNotify
{
    my ($self, $row) = @_;

    # Tag this share as needing a reset of rights.
    $self->tagShareRightsReset($row);
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

    # Tag this share as needing a reset of rights.
    $self->tagShareRightsReset($row);
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
                throw EBox::Exceptions::External(
                    __('The file system root directory cannot be used as share'));
            }
            foreach my $filterPath (FILTER_PATH) {
                if ($normalized =~ /^$filterPath/) {
                    throw EBox::Exceptions::External(
                        __x('Path not allowed. It cannot be under {dir}',
                            dir => $normalized));
                }
            }
            EBox::Validate::checkAbsoluteFilePath(
                $parms->{'path'}->value(), __('Samba share absolute path'));
            # Check if the filesystem is mounted with acl and user_xattr
            $self->_checkSystemShareMountOptions($normalized);
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
    my ($self) = @_;

    for my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $enabled     = $row->valueByName('enabled');
        my $shareName   = $row->valueByName('share');
        my $pathType    = $row->elementByName('path');
        my $guestAccess = $row->valueByName('guest');

        unless ($enabled) {
            next;
        }

        my $path = undef;
        if ($pathType->selectedType() eq 'zentyal') {
            $path = $self->parentModule()->SHARES_DIR() . '/' . $pathType->value();
        } elsif ($pathType->selectedType() eq 'system') {
            $path = $pathType->value();
        } else {
            EBox::error("Unknown share type on share '$shareName'");
        }
        unless (defined $path) {
            next;
        }

        my @cmds = ();
        # Just create the share folder, the permissions will be set later on EBox::Samba::_postServiceHook so we are
        # sure that the share is already created and Samba is reloaded with the new configuration.
        push (@cmds, "mkdir -p '$path'");
        EBox::Sudo::root(@cmds);
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

sub _checkSystemShareMountOptions
{
    my ($self, $normalized) = @_;

    # Get the mount point of the path
    my @shareStat = stat($normalized);
    my $shareDevice = $shareStat[0];

    my $mountPoint = $normalized;
    while ($mountPoint ne '/') {
        my $dir = dirname($mountPoint);
        my @dirStat = stat($dir);
        if ($dirStat[0] != $shareDevice) {
            # Device border crossed
            last;
        }
        $mountPoint = $dir;
    }

    my $fs = new Sys::Filesystem(mtab => '/etc/mtab');
    my @filesystems = $fs->filesystems(mounted => 1);
    my $options = $fs->options($mountPoint);
    my @options = split(/,/, $options);
    unless (grep (/acl/, @options)) {
        throw EBox::Exceptions::External(
            __x("The mount point '$mountPoint' must be mounted with " .
                "'acl' option. This is required for permissions to work ".
                "properly.", mountPoint => $mountPoint));
    }
    unless (grep (/user_xattr/, @options)) {
        throw EBox::Exceptions::External(
            __x("The mount point '$mountPoint' must be mounted with " .
                "'user_xattr' option. This is required for permissions to ".
                "work properly.", mountPoint => $mountPoint));
    }
    return 1;
}

1;
