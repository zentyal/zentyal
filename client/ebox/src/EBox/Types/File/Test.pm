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


package EBox::Types::File::Test;
use base 'EBox::Test::Class';
#

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;
use Test::File;

use File::Slurp qw(read_file write_file);

use lib '../../..';

use EBox::TestStubs;
use EBox::Types::Test;

use EBox::Types::File;




my $content = 'first';
my $secondContent = 'second';

my $path = '/tmp/ebox.type.file.test';


sub setEBoxTmp : Test(startup)
{
    EBox::TestStubs::setEBoxConfigKeys(tmp => '/tmp/');
}



sub clearFiles : Test(setup)
{
    system "rm -f $path";

    my $file = newFile();
    my @toDelete = ($file->tmpPath, $file->path, $file->backupPath, $file->noPreviousFilePath);
    system (" rm -f @toDelete"); 
}

sub newTest : Test(1)
{
    EBox::Types::Test::createOk(
                                'EBox::Types::File',
                                filePath => $path,
                                fieldName => 'fileTest',
                               );
}



sub restoreWithoutBackup : Test(2)
{
    my $file = newFile();

    lives_ok {
        $file->restoreFiles()
    } ' restore without previous backup or file';
    write_file($path, $content);
    
    file_exists_ok($path, 'Checking that restore without previous file deletes ');
}


sub restoreWithoutBackup: Test(4)
{
    my $file = newFile();

    write_file($path, $content);
    lives_ok {
        $file->restoreFiles()
    } ' restore with backup of no existent file';

    my $actualContent = read_file($path);
    is $actualContent, $content, 
        'Checking that restore without backup does not alter the existent file';

    unlink $path;

        lives_ok {
        $file->restoreFiles()
    } ' restore with backup of no existent file';

    Test::File::file_not_exists_ok($path, "checking that restore without backup does not bring back deleted files");
}


sub restoreWithoutPreviousFile : Test(3)
{
    my $file = newFile();


    
    # backup of a not existent file
    lives_ok {
        $file->backupFiles()
    } 'backup of a not existent file';
    

    write_file($path, $content);
    lives_ok {
        $file->restoreFiles()
    } ' restore with backup of no existent file';

    Test::File::file_not_exists_ok($path, "checking that restore bckup done without files erases the new file");

}


sub restoreWithPreviousFile : Test(5)
{
    my $file = newFile();
    write_file($path, $content);

    lives_ok {
        $file->backupFiles()
    } 'backup with file';

    unlink $path;
    lives_ok {
        $file->restoreFiles();
    } 'restore after deleting file';
    my $actualContent = read_file($path);
    is $actualContent, $content, 
         'Checking if the restored file after removal has the right content';


    write_file($path, $secondContent);
    lives_ok {
        $file->restoreFiles();
    } 'restore after replacing file with another';
    is $actualContent, $content, 
        'Checking if the restored file after being replaced has the right content';

}


sub isEqualToTest : Test(5)
{
    my $file = newFile();
    my $file2 = newFile();

    clearFiles();
    ok $file->isEqualTo($file2), 'Checking equalTo in identical files objects';

    clearFiles();
    write_file($path, $content);
    ok $file->isEqualTo($file2), 'Checking equalTo in identical files objects  with file already in place';

    clearFiles();
    write_file($path, $content);
    write_file($file2->tmpPath(), $content);
    ok $file->isEqualTo($file2), 'Checking equalTo in identical files objects with the same file already in place and upload file';
    
    
    my $notEqual;

    clearFiles();
    write_file($path, $content);
    write_file($file2->tmpPath(), 'differentContent');
    $notEqual = not $file->isEqualTo($file2);
    ok  $notEqual, 'Checking equalTo in identical files objects with a file already in place and another upload file';

    clearFiles();
    write_file($file2->tmpPath(), $content);
    $notEqual = not $file->isEqualTo($file2);
    ok $notEqual, 'Checking equalTo in identical files objects without a file  in place and upload file';
}


sub existsTest : Test(2)
{
    my $file = newFile();

    ok (not $file->exist);

    write_file($path, $content);
    ok $file->exist;
}




sub printableValueTest : Test(2)
{
    my $path = '/tmp/ea.jpg';
    my $expectedPrintableValue = 'ea.jpg';

    my $fileWithStaticPath =  EBox::Types::File->new(
                                      filePath => $path,
                                      fieldName => 'fileTest',
                                     );

    is $fileWithStaticPath->printableValue(),
        $expectedPrintableValue,
            'checking printableValue in file with hardcoded path';

    my $dynamicPathSub = sub {  return $path };

    my $fileWithDynamicPath =  EBox::Types::File->new(
                                      dynamicPath => $dynamicPathSub,
                                      fieldName => 'fileTest',
                                     );

    is $fileWithDynamicPath->printableValue(),
        $expectedPrintableValue,
            'checking printableValue in file with dynamic path';
}





sub filesPaths : Test(2)
{
    my $file = EBox::Types::File->new(
                                      filePath => $path,
                                      fieldName => 'fileTest',
                                     );

    is_deeply( 
              $file->filesPaths(), 
              [],
     'Checking return value of filesPaths when no file is present '
             );

    write_file($path, $content);
    is_deeply (
               $file->filesPaths(), 
               [ $path ],
        'Checking return value of filesPaths when file is present '
              );
    

}



sub newFile
{
    my $file = EBox::Types::File->new(
                                      filePath => $path,
                                      fieldName => 'fileTest',
                                     );
    
    # remove previous backup path
    my $backupPath = $file->backupPath();
    system "rm -f $backupPath";

    return $file;
}





1;
