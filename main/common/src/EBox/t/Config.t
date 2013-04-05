use strict;
use warnings;

use Test::More 'no_plan';

use lib '../..';
use Fatal qw(open close mkdir);
use EBox::TestStub;

EBox::TestStub::fake();
use_ok 'EBox::Config';
configkeyFromFileTest();

sub configkeyFromFileTest
{
    my $configFileDir = '/tmp/ebox.test';
    my $configFile    = "$configFileDir/file.keys";

    my %configuration = (
        lemur => 'indri',
        mono  => 'macaco',
        simio => 'bonobo',
    );

    # preparing config file..
    system "rm -rf $configFileDir" if ( -e $configFileDir);
    ($? == 0) or die "Can not clean temporally test dir $configFileDir";
    mkdir $configFileDir;
    _createTestFile($configFile, %configuration);

    while (my ($configKey, $configValue) = each %configuration) {
        my $oldConfigKey = $configKey;
        my $gettedConfigValue = EBox::Config::configkeyFromFile($configKey, $configFile);

        is $gettedConfigValue, $configValue;
        is $configKey, $oldConfigKey, "Checking that configkeyFromFile does not change the supplied key parameter";
    }
}

sub _createTestFile
{
    my ($file, %keysAndValues) = @_;

    open (my $FH, ">$file");
    while (my ($key, $value) = each %keysAndValues  ) {
        print $FH "$key=$value\n";
    }

    close $FH;
}

1;
