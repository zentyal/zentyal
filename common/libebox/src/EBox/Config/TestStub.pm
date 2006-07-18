package EBox::Config::TestStub;
# Description:
# 
use strict;
use warnings;

use Test::MockModule;
use Perl6::Junction qw(all);
use EBox::Config;

# XXX: Derivated paths are ttoally decoupled from their base path (datadir, sysconfdir, localstatedir, libdir)
# possible solution 1:  rewrite EBox::Config so the derivated elements use a sub to get the needed element
# possible solution 2: rewrite this package to have specialized fakes for those subs

my $fakedConfigPackage = undef;
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


sub fake
{
    my @fakedConfig = @_;


    if (defined $fakedConfigPackage) {
	return;
    }

    if ( @fakedConfig > 0)  {
	_checkConfigKeysParameters(@fakedConfig);
    }

    $fakedConfigPackage = new Test::MockModule('EBox::Config');

    if ( @fakedConfig > 0)  {
	setConfigKeys(@fakedConfig);
    }
}


sub _checkFakeParams
{
    my %params = @_;
    

}

sub unfake
{
    defined $fakedConfigPackage or die "Module was not faked";
    $fakedConfigPackage->unmock_all();
    $fakedConfigPackage = undef;
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
    my %fakedConfig = @_;

    if (!defined $fakedConfigPackage) {
	die "Must fake first call EBox::Config::Fake::fake before setting config keys";
    }

    _checkConfigKeysParameters(@_);
 

    # fake config keys..
    while ( my ($configKey, $fakedResult) = each %fakedConfig ) {
	$fakedConfigPackage->mock($configKey => $fakedResult );
    }
}




1;
