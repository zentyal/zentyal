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

package EBox::Squid::Model::DomainFilterFilesBase;
use base 'EBox::Model::DataTable';
#

use strict;
use warnings;

use EBox;
use EBox::Gettext;
use EBox::Squid::Types::DomainPolicy;
use EBox::Types::File;
use EBox::Types::Text::WriteOnce;
use EBox::Types::HasMany;
use EBox::Sudo;

use Error qw(:try);
use Perl6::Junction qw(any);
use File::Basename;


use constant LIST_FILE_DIR => '/etc/dansguardian/extralists';

my $anyArchiveFilesScopes = any(qw(domains urls));


sub new
{
    my ($class, @p) = @_;
    return $class->SUPER::new(@p);
}

sub _tableHeader
  {
      my ($class) = @_;

      my @tableHeader =
        (
         new EBox::Types::Text::WriteOnce(
                               fieldName => 'description',
                               printableName => ('Description'),
                               unique   => 1,
                               editable => 1,
                              ),
         new EBox::Types::HasMany(
                                  'fieldName' => 'categories',
                                  'printableName' => __('Categories'),
                                  'foreignModel' => $class->categoryForeignModel(),
                                  'view' => $class->categoryForeignModelView(),
                                  'backView' => $class->categoryBackView(),
                                  'size' => '1',
     ),
         new EBox::Types::File(
                               fieldName     => 'fileList',
                               printableName => __('File'),
                               unique        => 1,
                               editable      => 1,
                               optional      => 1,
                               allowDownload => 1,
                               dynamicPath   => \&_listFilePath,
                               
                               user   => 'root',
                               group  => 'root',
                              ),
         

        );
      
      return \@tableHeader;
}


sub _listFilePath
{
    my ($file) = @_;
    my $row = $file->row();
    defined $row or
        return undef;


    my $model = $file->model();
    


    my $id = $model->_fileId($row);

    my $path = $model->listFileDir(); 
    $path .= '/' . $id;

#    EBox::debug("File path $path");

    return $path;
}


sub listFileDir
{
    throw EBox::Exceptions::NotImplemented('listFileDir');
}

sub _fileId
{
    my ($self, $row) = @_;
    my $id;

    $id  = $row->valueByName('description');
    $id =~ s/\s/_/g;

    return $id;
}


sub archiveContentsDir
{
    my ($self, $id) = @_;
    defined $id or
        $id = '';

    my $dir = $self->listFileDir() . '/archives/' . $id;
    if (-d $dir) {
        EBox::Sudo::root("mkdir -m 0755 -p $dir");
    }

    return $dir;
}


sub addedRowNotify
{
  my ($self, $row) = @_;
  
  $self->_checkRow($row);
}


sub udpatedRowNotify
{
  my ($self, $row) = @_;

  $self->_checkRow($row);
}




sub _checkRow
{
    my ($self, $row) = @_;

  try {
      my $fileList =  $row->elementByName('fileList');
    if (not $fileList->exist()) {
        throw EBox::Exceptions::External(
       __('You must supply a domains list')
                                        )
    }

      my $path = $fileList->path();
      if ($self->_fileIsArchive($path)) {
          $self->_setUpArchive($row);
      }
      else {
          $self->_checkFileList($path);
      }


  }
  otherwise {
      my $ex = shift;
      my $id = $row->id();
      $self->removeRow($id);
      $ex->throw();
  };

}



sub _archiveIsSettedUp
{
    my ($self, $row) = @_;

    my $id =  $self->_fileId($row);
    my $dir = $self->archiveContentsDir($id);

    return EBox::Sudo::fileTest('-d', $dir);
}

sub _setUpArchive
{
    my ($self, $row) = @_;
    my $fileList =  $row->elementByName('fileList');

    if (not $fileList->exist()) {
        throw EBox::Exceptions::External(
       __('Inexistent archive file')
                                      );
    }

    my $path = $fileList->path();

    my $fileId =  $self->_fileId($row);
    $self->_cleanArchive($fileId);
    $self->_extractArchive($path, $fileId);
    $self->_populateCategories($row);

}


sub _checkFileList
{
    my ($self, $path) = @_;
    
    # XXX to speed up the release we dont support plain lists yet i nthe next
    # version we will acommodate them to gui (maybe given it a bogus 'all'
    # cathegory or whatever'
    throw EBox::Exceptions::External(
 __('Plain lists not allowed: is only allowed compressed archives of classified black lists')
       );

    # XXX commented out bz there a lot of 'domains' list that are in 
    # reality 'url' lsits (in DG lingo). so we cannot afford be too strict

#     my @lines = @{ EBox::Sudo::root("/bin/cat $path")  };

#     foreach my $line (@lines) {
#         chomp $line;
#         $line =~ s/#.*$//;
#         $line =~ s/^\s+//;
#         $line =~ s/\s+$//;

#         if ($line =~ m/^\s*$/) {
#             next;
#         }

#         my ($domain, $path) = $line =~ m{^(.*?)/(.*)$};
#         defined $domain or
#                $domain = $line;


#         if (not EBox::Validate::checkDomainName($line)) {
#             throw EBox::Exceptions::External(
#            __x(
#               q{Invalid line: {li}} . 
#               qq{\n It must be either a domain name or a IP address},
#                li => $line
#               )
#                                             );
#         }

#         if ($path) {
#          if (not EBox::Validate::checkFilePath($path)) {
#               throw EBox::Exceptions::External(
#             __x(
#                q{Invalid line: {li}} . 
#                qq{\n It must be either a domain name or a IP address},
#                 li => $line
#                )
#                                             );
#           }
#      }
#     }

}

# Function: banned
#
#       Fetch the banned domains files
#
# Returns:
#
#       Array ref - containing the files
sub banned
{
  my ($self) = @_;
  return $self->_filesByPolicy('deny', 'domains');
}


# Function: allowed
#
#       Fetch the allowed domains files
#
# Returns:
#
#       Array ref - containing the files
sub allowed
{
  my ($self) = @_;
  return $self->_filesByPolicy('allow', 'domains');
}


# Function: filtered
#
#       Fetch the filtered domains files
#
# Returns:
#
#       Array ref - containing the files
sub filtered
{
  my ($self) = @_;
  return $self->_filesByPolicy('filter', 'domains');
}


# Function: bannedUrls
#
#       Fetch the banned urls files
#
# Returns:
#
#       Array ref - containing the files
sub bannedUrls
{
  my ($self) = @_;
  return $self->_filesByPolicy('deny', 'urls');
}


# Function: allowedUrls
#
#       Fetch the allowed urls files
#
# Returns:
#
#       Array ref - containing the files
sub allowedUrls
{
  my ($self) = @_;
  return $self->_filesByPolicy('allow', 'urls');
}


# Function: filteredUrls
#
#       Fetch the filtered urls files
#
# Returns:
#
#       Array ref - containing the files
sub filteredUrls
{
  my ($self) = @_;
  return $self->_filesByPolicy('filter', 'urls');
}



sub _filesByPolicy
{
  my ($self, $policy, $scope) = @_;
  ($scope eq $anyArchiveFilesScopes) or
      throw EBox::Exceptions::Internal("Bad scope $scope");

  my @files = ();
  foreach my $id (@{$self->ids()}) {
      my $row = $self->row($id);
      my $file = $row->elementByName('fileList');
      $file->exist() or 
          next;
      
      my $path = $file->path();
      if ($self->_fileIsArchive($path)) {
          push @files,  @{ $self->_archiveFiles($row, $policy, $scope)  };
            }
      else {
          if ($scope eq 'urls') {
              #for now individual files are *always* domains lists
              next;
          }

          if ($row->valueByName('policy') eq $policy) {
              push @files, $path;                
          } 
          
      }

  }

  return \@files;
}



sub _fileIsArchive
{
    my ($self, $path) = @_;
    my $output = EBox::Sudo::root("/usr/bin/file -b $path");
    if ($output->[0] =~ m/^gzip compressed/) {
        return 1;
    }
    else {
        return 0;
    }

}


sub _cleanArchive
{
    my ($self, $id) = @_;
    my $dir = $self->archiveContentsDir($id);
    EBox::Sudo::root("rm -rf $dir");

}

sub _extractArchive
{
    my ($self, $path, $id) = @_;
    my $dir = $self->archiveContentsDir($id);
    EBox::Sudo::root("mkdir -p $dir");

    my $cmd = "tar  xzf $path -C $dir ";
    EBox::Sudo::root($cmd);
    my $owner = $self->_archiveFilesOwner();

    EBox::Sudo::root("chown -R $owner $dir");
}


sub _archiveFilesOwner
{
    return 'root.root';
}





sub _archiveFiles
{
     my ($self, $row, $policy, $scope) = @_;

     # we must do the below to recuperate from discard changes!!
     if (not $self->_archiveIsSettedUp($row)) {
         $self->_setUpArchive($row);
     }

     my $domainFilterCategories = $row->subModel('categories');
     return $domainFilterCategories->filesPerPolicy($policy, $scope);
}



sub _populateCategories
{
    my ($self, $row) = @_;
    
    my %categories;
    
    my $id = $self->_fileId($row);
    my $dir = $self->archiveContentsDir($id);
    my @files =  @{ EBox::Sudo::root("find $dir") };
    foreach my $file (@files) {
        chomp $file;
        $file =~ m{^(.*)/(.*?)/(.*?)$};
        my $dirname  = $1 .'/' . $2;
        my $category = $2;
        my $basename = $3;
        
        if ($basename eq $anyArchiveFilesScopes) {
            $categories{$category} = $dirname;
         }
        
    }
    
    
    my $domainFilterCategories = $row->subModel('categories');

    my %categoriesInModel = map { 
                                     ($_ => 1)  
                              } @{ $domainFilterCategories->categories() };

    # add new categories
    while (my ($category, $dir) = each %categories ) {
        if (exists $categories{$category}) {
            delete $categoriesInModel{$category};
            next;
        }

        $domainFilterCategories->addRow( 
                                        category => $category, 
                                        policy => 'ignore', 
                                        dir    => $dir,
                                       );
    }
        
    # remov categories not longer existent
    foreach my $category (keys %categoriesInModel) {
        $domainFilterCategories->deleteCategory($category);
    }
}


sub setupArchives
{
    my ($self) = @_;

#     my $dir = $self->listFileDir();
#     if (not -d $dir) {
#         EBox::Sudo::root(" mkdir -p -m 0755 $dir");
#     }

    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $fileList =  $row->elementByName('fileList');
        my $path = $fileList->path();

        if (not $fileList->exist()) {
         EBox::error(
"File $path refered as dansguardian domains list does not exists. Skipping"
                   );
            next;
        }

      if ($self->_fileIsArchive($path)) {
          $self->_setUpArchive($row);
      }
    }
}



sub cleanOrphanedFiles
{
    my ($self) = @_;

    my $dir = $self->listFileDir();
    (-d $dir) or
        return;

    my %expectedFiles;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $fileList = $row->elementByName('fileList');
        my $path = $fileList->path();
        if (not $fileList->exist()) {
            EBox::error(
  "Expected file does not exist: $path. Skipping it"
               );
            next;
        }

        $expectedFiles{$path} = 1;
    }

    my @listFiles = @{ EBox::Sudo::root("find $dir -maxdepth 1 -type f") }; 
    foreach my $file (@listFiles) {
        chomp $file;

        # see if is a correct file, otherwise delete it
        if (not exists $expectedFiles{$file}) {
            EBox::Sudo::root("rm $file");
        }
    }

    my $archivesDirBase = $self->archiveContentsDir();
    (-d $archivesDirBase) or
        return;

    # now check the arvhice dirs and delete leftovers
    my $archivesDirs = EBox::Sudo::root("find $archivesDirBase -maxdepth 1 -type d");
    foreach my $archDir (@{ $archivesDirs }) {
        chomp $archDir;
        if ($archDir eq $archivesDirBase) {
            next;
        }

        my $basename = basename($archDir);
        my $archiveFile = $dir . '/' . $basename;
        if (exists $expectedFiles{$archiveFile}) {
            next;
        }

        EBox::debug("Orphaned content dir $archDir. (Looked for file $archiveFile. Will be removed");
        EBox::Sudo::root("rm -rf $archDir");
        
    }
}



# sub _rmDirIfEmpty
# {
#     my ($package, $dir) = @_;

#     EBox::Sudo::root("rmdir --ignore-fail-on-non-empty $dir");
# }



# sub parentRow
# {
#     my ($self, @p) = @_;

#     use Devel::StackTrace;

#   my $trace = Devel::StackTrace->new;
#     EBox::debug($trace->as_string);

    
#     $self->SUPER::parentRow(@p);
# }


# sub setParentComposite
#     {
#     my ($self, @p) = @_;

#     use Devel::StackTrace;

#   my $trace = Devel::StackTrace->new;
#     EBox::debug($trace->as_string);

    
#     $self->SUPER::setParentComposite(@p);
# }


# XXX ad-hack reimplementation until the bug in coposite's parent would be
# solved 
use EBox::Global;
sub parent
{
    my ($self) = @_;

    my $squid     = EBox::Global->modInstance('squid');
    my $filterProfiles = $squid->model('FilterGroup');
    return $filterProfiles;
}


sub _backupFilterFilesArchive
{
    my ($self, $dir) = @_;
    return "$dir/filterFiles.tar.gz";
}

sub dumpConfig
{
    my ($self, $dir) = @_;

    if ($self->size() == 0) {
        # nothing to backup then
        return;
    }

    my $toBackupList = '/tmp/ebox.domainfilesfilter';
    open my $fh, ">$toBackupList" or
        throw EBox::Exceptions::Internal("$!");

    foreach my $id (@{ $self->ids() } ) {
        my $fileField = $self->row($id)->elementByName('fileList');
        $fileField->exist() or
            next;
        print $fh $fileField->path() . "\n";
    }
    
    close $fh or
         throw EBox::Exceptions::Internal("$!");


    
    my $archiveFile = $self->_backupFilterFilesArchive($dir);

    my $tarCmd;
    if (not -e $archiveFile) {
        $tarCmd = "tar -C '/' -cf $archiveFile --files-from '$toBackupList'";
    }else {
        $tarCmd = "tar -C '/' -rf $archiveFile --files-from '$toBackupList'";
    }

    EBox::Sudo::root($tarCmd);
}


# this must be only called one time
sub restoreConfig
{
    my ($class, $dir)  = @_;

 #   $class->_rmAllFilterFiles();

    my $archiveFile = $class->_backupFilterFilesArchive($dir);

    if (not -r $archiveFile) {
        return;
    }

    my $tarCmd = "tar --preserve -C'/' -xf '$archiveFile'";
    EBox::Sudo::root($tarCmd);

    # a little awkward, to call forth-and-back but we must asuuse that all fitler
    # profiles files are in order
    my $squid = EBox::Global->modInstance('squid');
    $squid->_cleanDomainFilterFiles(orphanedCheck => 1);
}


sub _rmAllFilterFiles
{
    my ($self) = @_;
    EBox::Sudo::root('rm -rf ' . LIST_FILE_DIR . '/*');
}




# this two methods ar empty until automatic files backup/restore is fixed
# until then we wil l use the custom dumpConfig and restoreConfig methods
sub backupFiles
{} 

sub restoreFiles
{}
1;
