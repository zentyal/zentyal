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



EBox::TestStubs::activateTestStubs();

my $content = 'first';
my $secondContent = 'second';

my $path = '/tmp/ebox.type.file.test';




sub clearFile : Test(startup)
{
    system "rm -f $path";
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
        $file->restore()
    } ' restore without previous backup or file';
    write_file($path, $content);
    
    file_exists_ok($path, 'Checking that restore without previous file deletes ');
}


sub restoreWithoutPreviousFile : Test(3)
{
    my $file = newFile();


    
    # backup of a not existent file
    lives_ok {
        $file->backup()
    } 'backup of a not existent file';
    

    write_file($path, $content);
    lives_ok {
        $file->restore()
    } ' restore with backup of no existent file';

    my $actualContent = read_file($path);
    is $actualContent, $content, 
        'Checking that restore without backup does not alter the existent file';
}


sub restoreWithPreviousFile : Test(5)
{
    my $file = newFile();
    write_file($path, $content);

    lives_ok {
        $file->backup()
    } 'backup with file';

    unlink $path;
    lives_ok {
        $file->restore();
    } 'restore after deleting file';
    my $actualContent = read_file($path);
    is $actualContent, $content, 
         'Checking if the restored file after removal has the right content';


    write_file($path, $secondContent);
    lives_ok {
        $file->restore();
    } 'restore after replacing file with another';
    is $actualContent, $content, 
        'Checking if the restored file after being replaced has the right content';

}

sub newFile
{
    my $file = EBox::Types::File->new(
                                      filePath => $path,
                                      fieldName => 'fileTest',
                                     );
    
    # remove previous backup apth
    my $backupPath = $file->backupPath();
    system "rm -f $backupPath";

    return $file;
}

1;
