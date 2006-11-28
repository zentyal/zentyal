package main;
# Description:
use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;
use Test::File;
use Test::MockObject;

use English qw( -no_match_vars ) ;  # Avoids regex performance penalty
use File::Slurp;

use lib '../..';

use EBox::TestStub;
use EBox::Config::TestStub;

# first mock EBox::Sudo to avoid import problems...
use EBox::Sudo::TestStub;
EBox::Sudo::TestStub::fake();

use_ok ('EBox::Module');
writeConfFileTest();



sub writeConfFileTest
{
    my $testDir        = '/tmp/ebox.test';
    my $testFile       = "$testDir/confFile.test";
    my $wantedMode     = '0700'; 

    # mason stuff.. 
    my $masonComponent = 'Inexistent.mas';
    my $masonParams    = [importance => 0];

    # setup..
    filesSetup($testDir, $testFile, $wantedMode);
    testStubsSetup($testDir, $testFile);
    
    ## Test cases:

    # file exists and stat succeed case
    lives_ok {  EBox::Module->writeConfFile($testFile, $masonComponent, $masonParams) } 'EBox::Module::writeConfFile execution upon a existent file';
    # check results
    file_exists_ok $testFile;
    file_mode_is ($testFile, oct $wantedMode);

   
    # file does not exist
    unlink $testFile or die "Cannot unlink test file $testFile";
    my @gids =  split '\s', $GID ;
    my $defaults = { mode => $wantedMode, uid => $UID, gid => $gids[0] };
    lives_ok {  EBox::Module->writeConfFile($testFile, $masonComponent, $masonParams, $defaults) } 'EBox::Module::writeConfFile execution upon a inexistent file';
    file_exists_ok $testFile;
    file_mode_is ($testFile, oct $wantedMode);

#    Cannot execute this testcase because by default chowns to root!
#     # called without any optional parameter
#     my $defaultMode = '0644';
#     unlink $testFile or die "Cannot unlink test file $testFile";
#     lives_ok {  EBox::Module->writeConfFile($testFile, $masonComponent) } 'EBox::Module::writeConfFile execution without any optional parameter';
#     file_exists_ok $testFile;
#     file_mode_is ($testFile, oct '0644');
}



sub filesSetup
{
    my ($testDir, $testFile, $wantedMode) = @_;

    system "rm -rf $testDir"; 
    ($? == 0) or die "Cannot clean test dir $testDir";

    mkdir $testDir;

    system "touch $testFile";
    ($? == 0) or die "Cannot create testFile $testFile";
    system "chmod $wantedMode $testFile";
    ($? == 0) or die "Cannot change mode of test file $testFile";

 
}


sub testStubsSetup
{
    my ($testDir, $testFile) = @_;

    EBox::TestStub::fake();
    EBox::Sudo::TestStub::fake();

    EBox::Config::TestStub::fake();
    EBox::Config::TestStub::setConfigKeys(tmp => $testDir);    

#    _mockFileStat();

   _setMasonOutpuFile($testFile);
    _mockMasonInterp();
 }

MOCK_MASON: {
    my $fileToCreate;

    sub _newMasonInterpObject
    {
	my ($class, %params) = @_;

	my $mockedInterp = new Test::MockObject;
	my $outMethod =$params{out_method};
	defined $outMethod or die "Need a out_method..";
	

	$mockedInterp->mock('make_component' => sub { return 'fake_component' });
	$mockedInterp->mock('exec' => sub { 
	    $outMethod->("Printed by mocked interp");
	    } );

	return $mockedInterp;
    }

    sub _mockMasonInterp
    {
	Test::MockObject->fake_module('HTML::Mason::Interp', 'new' => \&_newMasonInterpObject );
    }

    sub _setMasonOutpuFile
    { 
	my ($file) = @_;
	$fileToCreate = $file;
    }


};

sub _destroyFileStat
{


    my $destroyCode = 'no warnings "redefine"; sub File::stat::stat ($)  { return undef } ';
    eval $destroyCode;
    if ($@) {
	throw EBox::Exception::Internal($@);
    }



};








1;
