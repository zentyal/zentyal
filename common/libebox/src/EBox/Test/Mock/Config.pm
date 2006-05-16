package EBox::Test::Mock::Config;
# Description:
# 
use strict;
use warnings;
#use Smart::Comments; # turn on for debug purposes
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
    my %mockedConfig = @_;

    _checkMockParams(@_);

    if (!defined $mockedConfigPackage) {
	$mockedConfigPackage = new Test::MockModule('EBox::Config');
    }

    while ( my ($configKey, $mockedResult) = each %mockedConfig ) {
	$mockedConfigPackage->mock($configKey => $mockedResult );
    }
}


sub _checkMockParams
{
    my %params = @_;
    
    if (@_ == 0) {
	die "It has not any sense to call mock sub without parameters";
    }

    my $allCorrectParam = all (keys %config);
    my @incorrectParams = grep { $_ ne $allCorrectParam } keys %params;

    if (@incorrectParams) {
	die "mock called with the following incorrect named parameters: @incorrectParams";
    }
}

sub unmock
{
    defined $mockedConfigPackage or die "Module was not mocked";
    $mockedConfigPackage->unmock_all();
}


1;
