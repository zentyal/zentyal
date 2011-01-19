# Copyright (C) 2008-2010 eBox Technologies S.L.
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

# Class: EBox::Samba::Model::SambaShares
#
#  This model is used to configure shares different to those which are
#  given by the group share
#
package EBox::Samba::Model::SambaShares;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use Cwd 'abs_path';
use String::ShellQuote;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Boolean;
use EBox::Model::ModelManager;
use EBox::Exceptions::DataInUse;
use EBox::SambaLdapUser;
use EBox::Sudo;

use Error qw(:try);

use constant EBOX_SHARE_DIR => EBox::SambaLdapUser::basePath() . '/shares/';
use constant DEFAULT_MASK => '0670';
use constant DEFAULT_USER => 'ebox';
use constant DEFAULT_GROUP => '__USERS__';
use constant GUEST_DEFAULT_MASK => '0750';
use constant GUEST_DEFAULT_USER => 'nobody';
use constant GUEST_DEFAULT_GROUP => 'nogroup';


# TODO
# Add more paths which don't make sense to allow as a share
#
use constant FILTER_PATH => ('/etc', '/boot', '/dev', '/root', '/proc');

# Dependencies

# Group: Public methods

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
      bless ( $self, $class);

      return $self;

}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
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
                                       fieldName     => 'ebox',
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
                               help => _pathHelp()),
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
                               'foreignModel' => 'SambaSharePermissions',
                               'view' =>
                                   '/ebox/Samba/View/SambaSharePermissions'
                              )

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
            for my $filterPath (FILTER_PATH) {
                if ($normalized =~ /^$filterPath/) {
                    throw EBox::Exceptions::External(
                            __('Path not allowed') .
                            ' (' . join (', ', FILTER_PATH) . ')'
                    );
                }
            }
        } else {
            # Check if it is a valid directory
            my $dir = $parms->{'path'}->value();
            unless ($dir =~ /^\w+$/) {
                throw EBox::Exceptions::External(
                        __('Only alphanumeric characters plus '
                            . '_ are valid for a path'));
            }
        }
    }

    # FIXME: Remove these checkings if configuration is written in UTF-8
    if (exists $parms->{'share'}) {
        my $shareName = $parms->{'share'}->value();
        unless ($shareName =~ /^[\0-\x7f]+$/) {
            throw EBox::Exceptions::External(
                __('Only ASCII characters are valid for a share name'));
        }
    }

    if (exists $parms->{'comment'}) {
        my $comment = $parms->{'comment'}->value();
        unless ($comment =~ /^[\0-\x7f]+$/) {
            throw EBox::Exceptions::External(
                __('Only ASCII characters are valid for a share description'));
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

    my $path =  EBOX_SHARE_DIR;
    $path .= $row->elementByName('path')->value();
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
    return unless ($path->selectedType() eq 'ebox');

    my $mgr = EBox::Model::ModelManager->instance();
    my $deletedModel = $mgr ->model('DeletedSambaShares');
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
        my $pathType =  $row->elementByName('path');
        next unless ( $pathType->selectedType() eq 'ebox');
        my $path = EBOX_SHARE_DIR . $pathType->value();
        my @cmds;
        push(@cmds, "mkdir -p $path");
        if ($row->elementByName('guest')->value()) {
           push(@cmds, 'chmod ' . GUEST_DEFAULT_MASK . " $path");
           push(@cmds, 'chown ' . GUEST_DEFAULT_USER . ':' . GUEST_DEFAULT_GROUP . " $path");
        } else {
           push(@cmds, 'chmod ' . DEFAULT_MASK . " $path");
           push(@cmds, 'chown ' . DEFAULT_USER . ':' . DEFAULT_GROUP . " $path");
        }
        push(@cmds, "setfacl -b $path");
        EBox::Sudo::root(@cmds);
        # ACLs
        my @perms;
        for my $subId (@{$row->subModel('access')->ids()}) {
            my $subRow = $row->subModel('access')->row($subId);
            my $permissions = $subRow->elementByName('permissions');
            next if ($permissions->value() eq 'administrator');
            my $userType = $subRow->elementByName('user_group');
            my $perm;
            if ($userType->selectedType() eq 'group') {
                $perm = 'g:';
            } elsif ($userType->selectedType() eq 'user') {
                $perm = 'u:';
            }
            my $qobject = shell_quote( $userType->printableValue());
            $perm .= $qobject . ':';

            if ($permissions->value() eq 'readOnly') {
                $perm .= 'rx';
            } elsif ($permissions->value() eq 'readWrite') {
                $perm .= 'rwx';
            }
            push (@perms, $perm);
        }
        next unless @perms;
        my $cmd = 'setfacl -m ' . join(',', @perms) . " $path";
        my $defaultCmd = 'setfacl -m d:' . join(',d:', @perms) ." $path";
        EBox::debug("$cmd and $defaultCmd");
        try {
            EBox::Sudo::root($cmd);
            EBox::Sudo::root($defaultCmd);
        } otherwise {
            EBox::debug("Couldn't enable ACLs for $path")
        };
    }
}


# Private methods
sub _pathHelp
{
    return __x( '{openit}Directory under Zentyal{closeit} will ' .
            'automatically create the share.' .
            'directory in /home/samba/shares {br}' .
            '{openit}File system path{closeit} will allow you to share '.
            'an existing directory within your file system',
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
