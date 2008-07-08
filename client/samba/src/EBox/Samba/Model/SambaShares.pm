# Copyright (C) 2008 Warp Networks S.L.
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

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Model::ModelManager;
use EBox::Exceptions::DataInUse;
use EBox::SambaLdapUser;
use EBox::Sudo;

use Error qw(:try);

use constant EBOX_SHARE_DIR => EBox::SambaLdapUser::basePath() . '/shares/';
use constant DEFAULT_MASK => '0670';
use constant DEFAULT_USER => 'ebox';
use constant DEFAULT_GROUP => '__USERS__';


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
                                            __('Directory under eBox'),
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
                     printableTableName => __('List of samba shares'),
                     pageTitle          => __('Samba shares'),
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

# Method: validateRow
# 
#       Override <EBox::Model::DataTable::validateRow> method
# 
#   Check if the share path is allowed or not
sub validateTypedRow()
{
    my ($self, $action, $parms)  = @_;

    return unless ($action eq 'add' or $action eq 'update');
    return unless (exists $parms->{'path'});
    
    my $path = $parms->{'path'}->selectedType();

    if ($path eq 'system') {
        # Check if it is an allowed system path
        my $normalized = abs_path($parms->{'path'}->value());
        for my $filterPath (FILTER_PATH) {
            if ($normalized =~ /^$filterPath/) {
                throw EBox::Exceptions::External(
                    __('Path not allowed'));
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

    for my $row (@{$self->rows()}) {
        my $pathType =  $row->elementByName('path');
        next unless ( $pathType->selectedType() eq 'ebox');
        my $path = EBOX_SHARE_DIR . $pathType->value();
        next if ( -d $path );
        try {
            EBox::Sudo::root("mkdir -p $path");
            EBox::Sudo::root('chmod ' . DEFAULT_MASK . " $path");
            EBox::Sudo::root('chown ' . DEFAULT_USER . ':' 
                             .  DEFAULT_GROUP . " $path");
        } otherwise {
            EBox::debug("Couldn't create dir $path");
        };
       
    }
}


# Private methods
sub _pathHelp
{
    return __( '<i>Directory under eBox</i> will ' .
            'automatically create the share.' . 
            'directory in /home/samba/shares <br>' .
            '<i>File system path</i> will allow you to share '.
            'an existing directory within your file system. ');

}

sub _sharesHelp
{
    return __('Here you can create shares with more fine-grained permission ' . 
              'control. ' .
              'You can use an existing directory or pick a name and let eBox ' .
              'create it for you.');
}
1;
