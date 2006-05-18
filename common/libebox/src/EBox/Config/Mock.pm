package EBox::Config::Mock;
# Description:
# 
use strict;
use warnings;

use Test::MockModule;
use Perl6::Junction qw(all);
use EBox::Config;

# XXX: Derivated paths are ttoally decoupled from their base path (datadir, sysconfdir, localstatedir, libdir)
# possible solution 1:  rewrite EBox::Config so the derivated elements use a sub to get the needed element
# possible solution 2: rewrite this package to have specialized mocks for those subs

my $mockedConfigPackage = undef;
my %config       = _defaultConfig();    # this hash hold the configuration items

sub _defaultConfig
{
    my @defaultConfig;

    my @configKeys = qw(prefix    etc var user group share libexec locale conf tmp passwd sessionid log logfile stubs cgi templates schemas www css images package version lang ); 
    foreach my $key (@configKeys) {
	my $configKeySub_r = EBox::Config->can($key);
	defined $configKeySub_r or die "Can not find $key sub in EBox::Config module";

	push @defaultConfig, ($key => $configKeySub_r->());
    }

    return @defaultConfig;
}


sub mock
{
    my @mockedConfig = @_;


    if (defined $mockedConfigPackage) {
	return;
    }

    if ( @mockedConfig > 0)  {
	_checkConfigKeysParameters(@mockedConfig);
    }

    $mockedConfigPackage = new Test::MockModule('EBox::Config');

    if ( @mockedConfig > 0)  {
	setConfigKeys(@mockedConfig);
    }
}


sub _checkMockParams
{
    my %params = @_;
    

}

sub unmock
{
    defined $mockedConfigPackage or die "Module was not mocked";
    $mockedConfigPackage->unmock_all();
    $mockedConfigPackage = undef;
}



sub _checkConfigKeysParameters
{
    my %params = @_;

   # check parameters...
    if (@_ == 0) {
	die "setConfigKeys called without parameters";
    }
    my $allCorrectParam = all (keys %config);
    my @incorrectParams = grep { $_ ne $allCorrectParam } keys %params;

    if (@incorrectParams) {
	die "called with the following incorrect config key names: @incorrectParams";
    }
}

sub setConfigKeys
{
    my %mockedConfig = @_;

    if (!defined $mockedConfigPackage) {
	die "Must mock first call EBox::Config::Mock::mock before setting config keys";
    }

    _checkConfigKeysParameters(@_);
 

    # mock config keys..
    while ( my ($configKey, $mockedResult) = each %mockedConfig ) {
	$mockedConfigPackage->mock($configKey => $mockedResult );
    }
}




1;
