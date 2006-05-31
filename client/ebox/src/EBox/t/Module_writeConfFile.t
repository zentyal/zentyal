package main;
# Description:
use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;
use Test::File;
use Test::MockModule;
use Test::MockObject;

use English qw( -no_match_vars ) ;  # Avoids regex performance penalty
use File::Slurp;

use lib '../..';

use EBox::Mock;

use EBox::Config::Mock;

# first mock EBox::Sudo to avoid import problems...
use EBox::Sudo::Mock;
EBox::Sudo::Mock::mock();

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
    mockSetup($testDir, $testFile);
    
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



}



sub filesSetup
{
    my ($testDir, $testFile, $wantedMode) = @_;

    system "rm -rf $testDir"; 
    ($? == 0) or die "Can not clean test dir $testDir";

    mkdir $testDir;

    system "touch $testFile";
    ($? == 0) or die "Can not create testFile $testFile";
    system "chmod $wantedMode $testFile";
    ($? == 0) or die "Can not change mode of test file $testFile";

 
}


sub mockSetup
{
    my ($testDir, $testFile) = @_;

    EBox::Mock::mock();
    EBox::Sudo::Mock::mock();

    EBox::Config::Mock::mock();
    EBox::Config::Mock::setConfigKeys(tmp => $testDir);    

#    _mockFileStat();

   _setMasonOutpuFile($testFile);
    _mockMasonInterp();
 }

MOCK_MASON: {
    my $mockedMasonInterpModule;
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
	$mockedMasonInterpModule = new Test::MockModule ('HTML::Mason::Interp');
	defined $mockedMasonInterpModule or die "Unable to mock HTML::Mason::Interp";
	$mockedMasonInterpModule->mock('new' => \&_newMasonInterpObject );
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
