# Copyright (C) 2009 Warp Networks S.L.
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

package main;

#

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;
use Test::File;

use lib '../..';
use EBox::Module;
use EBox::TestStubs qw(fakeEBoxModule);


EBox::TestStubs::activateTestStubs();
fakeEBoxModule(name => 'testMod');

my $dir = '/tmp/gconfmodule_files.t';



my $mod = EBox::Global->modInstance('testMod');

my @cases = (
             {
              name => 'simple saveConfig',
              actions => [
                           addFileToRemoveIfCommitted => [ 
                                                          "$dir/revoked1",
                                                          "$dir/revoked2",
                                                          # repeated entry
                                                          "$dir/revoked1",
                                                         ],
                           addFileToRemoveIfRevoked  => [
                                                         "$dir/committed1",
                                                        ],
                           _saveConfigFiles          => [],
                         ],
              expected => {
                           files =>  [
                                      "$dir/committed1",
                                     ],
                           filesDeleted => [
                                            "$dir/revoked1",
                                            "$dir/revoked2"
                                           ],
                          },
             },

             {
              name => 'simple revokeConfig',
              actions => [
                           addFileToRemoveIfCommitted => [ 
                                                          "$dir/revoked1",
                                                          "$dir/revoked2",
                                                          # repeated entry
                                                          "$dir/revoked1",
                                                         ],
                           addFileToRemoveIfRevoked  => [
                                                         "$dir/committed1",
                                                        ],
                           _revokeConfigFiles          => [],
                         ],
              expected => {
                           files =>  [
                                      "$dir/revoked1",
                                      "$dir/revoked2"
                                     ],
                           filesDeleted => [
                                      "$dir/committed1",
                                           ],
                          },
             },

             {
              name => 'revokeConfig with file after added to committed list',
              actions => [
                           addFileToRemoveIfCommitted => [ 
                                                          "$dir/revoked1",
                                                          "$dir/revoked2",
                                                          # repeated entry
                                                          "$dir/revoked1",
                                                         ],
                           addFileToRemoveIfRevoked  => [
                                                         "$dir/committed1",
                                                        ],
                           addFileToRemoveIfCommitted => [ 
                                                          "$dir/committed1",
                                                         ],
                           _revokeConfigFiles          => [],
                         ],
              expected => {
                           files =>  [
                                      "$dir/revoked1",
                                      "$dir/revoked2",
                                      "$dir/committed1",
                                     ],
                           filesDeleted => [

                                           ],
                          },
             },

             {
              name => 'saveConfig with file added afterwas to revoked remove list',
              actions => [
                           addFileToRemoveIfCommitted => [ 
                                                          "$dir/revoked1",
                                                          "$dir/revoked2",
                                                          # repeated entry
                                                          "$dir/revoked1",
                                                         ],
                           addFileToRemoveIfRevoked  => [
                                                         "$dir/committed1",
                                                        ],
                           addFileToRemoveIfRevoked => [ 
                                                          "$dir/revoked1",
                                                         ],
                           _saveConfigFiles          => [],
                         ],
              expected => {
                           files =>  [
                                      "$dir/committed1",
                                      "$dir/revoked1",
                                     ],
                           filesDeleted => [
                                            "$dir/revoked2"
                                           ],
                          },
             },

            );


foreach my $case (@cases) {
    _setUpDir($dir);
    _executeTestCase($case, $mod);
}


sub _executeTestCase
{
    my ($case, $mod) = @_;
    
    my $name = $case->{name};
    $name or $name = 'new test case';
    diag $name;

    my @actions = @{ $case->{actions } };
    while (@actions) {
        my $method = shift @actions;
        my $args   = shift @actions;
        if (@{ $args }) {
            foreach my $file (@{ $args }) {
                system "touch $file";
                $mod->$method($file);
            }
        } else {
            $mod->$method();
        }
        
    }


    my $expected = $case->{expected};
    my @filesSaved    =  @{ $expected->{files} };
    my @filesDeleted  =  @{ $expected->{filesDeleted} };

    foreach my $file (@filesSaved) {
        file_exists_ok($file);
    }
    foreach my $file (@filesDeleted) {
        file_not_exists_ok($file);
    }

    my @filesInFileLists = map {
        @{  $mod->_fileList($_) }
    } $mod->_fileListDirs();
    is 0, @filesInFileLists, 'Checking that file lists are empty';
}


sub _setUpDir
{
    my ($dir) = @_;
    system "rm -rf $dir";
    mkdir  $dir;
}

1;
