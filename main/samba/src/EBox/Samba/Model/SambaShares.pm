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
use EBox::Exceptions::External;
use EBox::Exceptions::DataInUse;
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
use File::Basename qw(dirname);
use File::Slurp;
use Cwd 'abs_path';
use TryCatch;

use constant FILTER_PATH => ('/bin', '/boot', '/dev', '/etc', '/lib', '/root',
                             '/proc', '/run', '/sbin', '/sys', '/var', '/usr',
                             '/opt');

use constant FILTER_FS_TYPES => ('vfat', 'msdos');

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
            editable      => 1,
            optional      => 1),
        new EBox::Types::Boolean(
            fieldName     => 'guest',
            printableName => __('Guest access'),
            editable      => 1,
            defaultValue  => 0,
            help          => __('This share will not require authentication.')),
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
        write_file(EBox::Config::conf() . "samba/sync_shares/$shareName");
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

    # Tag this share as needing a reset of rights.
    $self->tagShareRightsReset($row);
}

# Method: validateTypedRow
#
#       Override <EBox::Model::DataTable::validateTypedRow> method
#
#   Check if the share path is allowed or not
#
sub validateTypedRow
{
    my ($self, $action, $parms)  = @_;

    return unless ($action eq 'add' or $action eq 'update');

    if (exists $parms->{'path'}) {
        my $pathType = $parms->{'path'}->selectedType();
        my $pathValue = $parms->{'path'}->value();
        if ($pathType eq 'system') {
            # Check if it is an allowed system path
            my $normalized = abs_path($pathValue);
            unless (defined $normalized) {
                throw EBox::Exceptions::External(
                    __x("Zentyal could not access to directory '{x}': {y}",
                        x => $pathValue, y => $!));
            }
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

            unless (EBox::Sudo::fileTest('-d', $normalized)) {
                throw EBox::Exceptions::External(__x('Path {p} is not a directory', p => $normalized));
            }

            # Check if the filesystem is mounted with acl and user_xattr
            $self->_checkSystemShareMountOptions($normalized);
        } else {
            # Check if it is a valid directory
            EBox::Validate::checkFilePath($pathValue, __('Samba share directory'));
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

    my $path = $self->parentModule()->SHARES_DIR() . '/' . $row->valueByName('path');
    EBox::Sudo::silentRoot("ls $path/*");
    my $hasFiles = ($? == 0);
    if ($hasFiles) {
        throw EBox::Exceptions::DataInUse(
         __('The directory is not empty. Are you sure you want to remove it?'));
    }

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

    my $deletedModel = $self->parentModule->model('SambaDeletedShares');
    $deletedModel->addRow('path' => $path->value());
}

# Method: viewCustomizer
#
#   Overrided to show a warning when guest access is enabled for any share
#   and the domain guest account is disabled.
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = $self->SUPER::viewCustomizer();

    # Return if domain not yet provisioned or disabled
    my $sambaModule = $self->parentModule();
    unless ($sambaModule->isEnabled() and $sambaModule->isProvisioned()) {
        return $customizer;
    }

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        if ($row->valueByName('guest') and not $self->_guestAccountEnabled()) {
            my $msg = __x('Domain guest account should be enabled for guest ' .
                          'access to shares. You can enable it in the ' .
                          '{oh}users and groups manager{ch}.',
                          oh => "<a href='/Samba/Tree/Manage'>",
                          ch => "</a>");
            $customizer->setPermanentMessage($msg, 'warning');
            last;
        }
    }
    return $customizer;
}

# Private methods

sub _guestAccountEnabled
{
    my ($self) = @_;

    my $domainSid = EBox::Global->modInstance('samba')->ldap()->domainSID();
    my $domainGuestSid = "$domainSid-501";
    my $user = new EBox::Samba::User(sid => $domainGuestSid);
    return $user->isAccountEnabled();
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

    # Get FS type and throw exception if it is VFAT. This FS does not support
    # ACLs
    my $type;
    try {
        $type = $fs->type($mountPoint);
    } catch {
        throw EBox::Exceptions::External(__x('Error getting filesystem format in {m}', m => $mountPoint));
    }
    foreach my $filter (FILTER_FS_TYPES) {
        if ($type =~ /^$filter/) {
            throw EBox::Exceptions::External(
                __x("Filesystem format '{x}' does not support storing ACLs.", x => $type));
        }
    }

    # ext4, BTRFS, XFS, ZFS and GlusterFS have acl and extended attributes by default
    if (($type =~ m/ext4/) or ($type =~ m/btrfs/) or ($type =~ m/xfs/) or ($type =~ m/zfs/) or ($type =~ m/glusterfs/)) {
        return 1;
    }

    my $options;
    try {
        $options = $fs->options($mountPoint);
    } catch {
        throw EBox::Exceptions::External(__x('Error reading mount options in {m}', m => $mountPoint));
    }
    my @options = split(/,/, $options);
    unless (grep (/acl/, @options)) {
        throw EBox::Exceptions::External(
            __x("The mount point '{mountPoint}' must be mounted with " .
                "'acl' option. This is required for permissions to work ".
                "properly.", mountPoint => $mountPoint));
    }
    unless (grep (/user_xattr/, @options)) {
        throw EBox::Exceptions::External(
            __x("The mount point '{mountPoint}' must be mounted with " .
                "'user_xattr' option. This is required for permissions to ".
                "work properly.", mountPoint => $mountPoint));
    }
    return 1;
}

1;
