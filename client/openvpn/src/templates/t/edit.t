use strict;
use warnings;
use Cwd;

use lib '../..';
use EBox::Test::Mason;

use Test::More qw(no_plan);

my $printOutput = 0;
my $outputFile  = '/tmp/edit.html';
system "rm -rf $outputFile";

my $template =   getcwd() . '/../edit.mas';
my @compRoot = ('/usr/share/ebox/templates');

my @name = (name => 'testServer');
my %serverAttrs = (
		   service => 1,
		   port    => 10000,
		   subnet  => '192.168.132',
		   subnetNetmask => '255.255.255.0',
		   proto         => 'tcp',
		   clientToClient => 0,
		   local          => '192.168.133.41',
		   tlsRemote      => undef,
		  );

my @advertisedNets = (
		      { address => '192.168.134.0', netmask => '255.255.255.0' },
		      { address => '192.168.141.64', netmask => '255.255.255.192' },
		     );

my @certificates = ('macaco certificate', 'baboon certificate');

my @cases = (  
	     [ @name,  disabled => 1, availableCertificates => \@certificates, serverAttrs => \%serverAttrs, ],# disabled
	     [ @name,  disabled => 0, availableCertificates => [], serverAttrs => \%serverAttrs,],            # enabled with NO certificates
	     [ @name,  disabled => 0, availableCertificates => \@certificates, serverAttrs => \%serverAttrs,],# enabled
	     [ @name,  disabled => 0, availableCertificates => \@certificates, serverAttrs => \%serverAttrs, advertisedNets => \@advertisedNets ],# enabled
	    );







foreach my $params (@cases) {
  EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile, compRoot => \@compRoot);
}

1;
