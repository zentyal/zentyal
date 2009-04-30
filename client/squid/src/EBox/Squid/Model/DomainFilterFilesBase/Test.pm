# Copyright (C) 2009 EBox Technologies S.L.
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


package EBox::Squid::Model::DomainFilterFilesBase::Test;
use base 'EBox::Test::Class';

use Test::MockObject::Extends;
use Test::Exception;
use Test::File;
use Test::Differences;
use Test::More;
use File::Basename;
use English qw(-no_match_vars);

use lib '../../../..';

use EBox::Squid;
use EBox::Squid::Model::DomainFilterFilesBase;


my $tmpDir = '/home/javier/old/tmp';
#my $tmpDir = '/tmp';

sub addArchiveTest : Test(2)
{
    my ($self) = @_;

    my $filterFiles = $self->_newInstance();

    my $id = 'test';
    $self->_addShallaRow($filterFiles, $id);

    # check if the categories are populated
    my $row = $filterFiles->row($id);
    my $catModel = $row->subModel('categories');
    my %categoriesInModel = map {
        my $row = $catModel->row($_);
        ($row->valueByName('category') => 1)
    } @{ $catModel->ids() };

    my %shallaCategories = map {
        ( $_ => 1);
    } @{ $self->_shallalistCategories() };

    eq_or_diff( \%categoriesInModel,
        \%shallaCategories,
       'Checkign that categories were loaded in categories model correctly');

    my $allCorrectPolicy = 1;
    foreach my $id (  @{ $catModel->ids() } ) {
        my $row = $catModel->row($id);
        my $policy = $row->valueByName('policy');
        if ($policy ne 'ignore') {
            diag 'Bad policy in category ' . 
                  $row->valueByName('category');
            $allCorrectPolicy = 0;
        }
    }

    ok $allCorrectPolicy,
        'Checking that all new categories have the "ignore" policy';

}


sub discardTest : Test(3)
{
    my ($self) = @_;
    my $filterFiles = $self->_newInstance();

    my $id = 'added';
    $self->_addShallaRow($filterFiles, $id);

    my $file = $filterFiles->row($id)->elementByName('fileList')->path();
    my $dir  = $filterFiles->archiveContentsDir($id);

    # sanity test!
    (-e $file) or 
        die "archive fiel was not added";
    system "ls $dir/* > /dev/null";
    ($? == 0) or 
        die "no archive dir contents";

    my $squidUnmocked = EBox::Global->modInstance('squid');
    my $squid = new Test::MockObject::Extends($squidUnmocked);
    $squid->mock('model', 
                 sub {
                     my ($self, $name) = @_;
                     if ($name eq 'DomainFilterFiles') {
                         return $filterFiles;
                     }

                     return EBox::Model::ModelProvider::model($self, $name);
                 }
                );

    lives_ok {
        $filterFiles->removeAll(1); # XX needed by test setpu,
                                   # the nromal discard gconf changes does not
                                   # not work
        $squid->revokeConfig();
    } 'configuration revoked';

    file_not_exists_ok($file, 
          'checking that revokation deleted archive file');
    file_not_exists_ok($dir, 
           'whether revokation removed archives direcotory');
}


sub _addShallaRow
{
    my ($self, $filterFiles, $id) = @_;

    my $dir = $filterFiles->listFileDir();
    my $shallalist = $self->_shallalistPath();

    my $uploadFile = "$tmpDir/upload";
    system "cp $shallalist $uploadFile";
    system "cp $shallalist $dir/$id";

    $filterFiles->addRow(
        description => $id,
        fileList     => $uploadFile,
        id          => $id,
       );
}

sub dumpAndRestoreConfigTest : Test(11)
{
    my ($self) = @_;

    my $backupDir = "$tmpDir/domainfilterfilesbase.test.bdir";
    system "rm -rf $backupDir";
    system "mkdir -p $backupDir";

    my $filterFiles = $self->_newInstance();
    
    lives_ok {
        $filterFiles->dumpConfig($backupDir);
    } 'backing up a empty model';

    lives_ok {
        $filterFiles->restoreConfig($backupDir);
        $filterFiles->setupArchives();
        $filterFiles->cleanOrphanedFiles();
    } 'restoring up a empty model';

    my $dir = $filterFiles->listFileDir();
    my $shallalist = $self->_shallalistPath();
    my @filesToSave = ("$dir/save1", "$dir/save2", );
    my @filesToNotSave = ("$dir/noSave1", "$dir/noSave2");
    foreach my $file (@filesToNotSave) {
        system "echo 'content for noSAve $file' > $file";
    }

    foreach my $file (@filesToSave) {
        my $id = basename($file);
        my $uploadFile = "$backupDir/upload";
        system "cp $shallalist $uploadFile";
        system "cp $shallalist $file";

        $filterFiles->addRow(
            description => $id,
            fileList     => $uploadFile,
            id          => $id,
           );
    }
    

    lives_ok {
        $filterFiles->dumpConfig($backupDir);
    } 'backing up a  model';

    # remove fiels that shoudnt be restored
    system "rm @filesToNotSave";

    # mess a little with the files
    
    my $fileDeleted = "$dir/archives/save1/BL/dynamic/domains";
    my $dirThatMustNotExist =  "$dir/archives/mustNotExist";

    system "mv $dir/archives/save2 $dirThatMustNotExist";
    system "rm $fileDeleted";

    lives_ok {
        $filterFiles->restoreConfig($backupDir);
        $filterFiles->setupArchives();
        $filterFiles->cleanOrphanedFiles();
    } 'restoring up a  model';

    foreach my $file  (@filesToSave) {
        file_exists_ok($file, "Checking that file was correctly restored");
    }

    my @someFilesInLists = (
        "$dir/archives/save2/BL/politics/urls",
        $fileDeleted,
       );


    foreach my $file  (@someFilesInLists) {
        file_exists_ok($file, "Checking that file was correctly extracted");
    }

    file_not_exists_ok ($dirThatMustNotExist,
        'Checking that superfluous directoy has been deleted');

    foreach my $file  (@filesToNotSave) {
        file_not_exists_ok($file, 
      "Checking that files in the direcory but not in the model were not restored"
                          );
    }

    
}

sub _shallalistPath
{
    return '../DomainFilterFilesBase/testdata/shallalist.tar.gz';
}



sub _shallalistCategories
{
    my @cat = (
        'adv',
        'aggressive',
#        'automobile',
        'astronomy',
        'banking',
        'bikes',
        'boats',
        'cars',
        'chat',
        'chemistry',
        'cooking',
        'dating',
        'downloads',
        'drugs',
        'dynamic',
        'forum',
        'gamble',
        'games',
        'gardening',
        'hacking',
#        'hobby',
        'hospitals',
        'humor',
        'insurance',
        'imagehosting',
        'isp',
        'jobsearch',
        'lingerie',
        'military',
        'models',
        'moneylending',
        'movies',
        'music',
        'news',
        'other',
        'pets',
        'planes',
        'podcasts',
        'politics',
        'porn',
        'realestate',
#        'recreation',
        'redirector',
        'religion',
        'remotecontrol',
        'ringtones',
#        'science',
        'searchengines',
        'shopping',
        'socialnet',
        'sports',
        'spyware',
        'tracker',
        'travel',
        'updatesites',
        'violence',
        'warez',
        'weapons',
        'webmail',
        'webphone',
        'webradio',
        'webtv',
        'wellness',
#        'COPYRIGHT',
#        'global_usage',
#        'sex',
       );

    return \@cat;
}
sub orphanTest
{
# XXX TODO
}


sub startupModules : Test(startup)
{
    EBox::TestStubs::fakeEBoxModule(
        name => 'squid',
        package => 'EBox::Squid',
       );
}

sub startupDirectories : Test(startup)
{
    EBox::TestStubs::setEBoxConfigKeys('tmp' => $tmpDir);
}

sub setupListFileDir : Test(setup)
{
    my ($self) = @_;
    my $dir = $self->_listFileDir();
    system "rm -rf $dir";
    system "mkdir -p $dir";
}



sub _newInstance
{
    my ($self) = @_;
    
    my $squid = EBox::Squid->_create();

    my $base = EBox::Squid::Model::DomainFilterFilesBase->new(gconfmodule => $squid,
                                                              directory => 'DomainFilterFilesBaseTest',
                                                             );

    my $instance = Test::MockObject::Extends->new($base);
    $instance->mock('listFileDir', \&_listFileDir);
    $instance->mock('_table', \&_table);
    $instance->mock('_archiveFilesOwner', sub { 
                        my ($gid) = split '\s', $GID;
                        return "$UID.$gid" 
                       } 
         );

#     $instance->mock('categoryForeignModel' => \&_categoryForeignModel);
#     $instance->mock('categoryForeignModelView' => \&_categoryForeignModelView);
#     $instance->mock('categoryBackView' => &_categoryBackView);

    return $instance;

}




sub _listFileDir
{
    return "$tmpDir/DomainFilterFilesBase.test";
}

sub _table
  {
      my ($self) = @_;
      my $tableHeader = EBox::Squid::Model::DomainFilterFilesBase->_tableHeader();
      my $dataTable =
      {
          tableName          => 'TestDomainFilterFilesBase',
          printableTableName => 'Domains lists files',
          modelDomain        => 'Squid',
          'defaultController' => '/ebox/Squid/Controller/DomainFilterFiles',
          'defaultActions' =>
              [	
              'add', 'del',
              'editField',
              'changeView'
              ],
          tableDescription   => $tableHeader,
          class              => 'dataTable',
          order              => 0,
          rowUnique          => 1,
          printableRowName   => 'internet domain list',
          help               => 'You can uplaod fiels whith list of domains',
          messages           => {
                                  add => 'Domain list added',
                                  del => 'Domain list removed',
                                  update => 'Domain list updated',

                                },
          sortedBy           => 'description',
      };

  }




sub EBox::Squid::Model::DomainFilterFilesBase::categoryForeignModel
{
    return 'DomainFilterCategories';
}

sub EBox::Squid::Model::DomainFilterFilesBase::categoryForeignModelView
{
    return '/ebox/Squid/View/DomainFilterCategories';
}


sub EBox::Squid::Model::DomainFilterFilesBase::categoryBackView
{
    return '/ebox/Squid/Composite/FilterSettings';
}



sub EBox::Types::Abstract::setRow
{
    my ($self, $row) = @_;
    $self->{'row'} = $row;
}


1;
