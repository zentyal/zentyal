#!/usr/bin/perl

use EBox::CA;
use EBox::CA::DN;

sub printFile #(filePath)
  {
    my $filePath = shift;

    return undef if not $filePath;

    open(my $fd, "<" . $filePath) or die "$filePath $!";

    while (<$fd>) {
      print STDOUT $_;
    }

    close($fd);

  }

my $ca = EBox::CA->new();
my $ret;

#print "Create a CA...";
#$ret = $ca->createCA(orgName => "Warp Networks S.L.",
#	      countryName => "EU",
#	      stateName   => "Catalunya",
#		     days => 1400,
#	      caKeyPassword => "oooh");
#print "done\n";
#
#print "Revoke CA cert...";
#$ca->revokeCACertificate( reason => keyCompromise,
#			  caKeyPassword => 'oooh');
#print "done\n";
#print "Issue CA cert...";
#$ca->issueCACertificate(orgName => 'OOOHHHHH S.A.',
#			caKeyPassword => 'oooh',
#                        days => 23);
#print "done\n";
#
print "Renew CA cert...";
$ca->renewCACertificate(days => 230,
		        caKeyPassword => 'oooh');
print "done\n";
#
#print "\nShow CA Public Key...\n";
#my $pubKey = $ca->CAPublicKey("oooh");
#printFile($pubKey);
#print "done\n";
##
#
#print "\nIssue User Certificate...";
#my $userCert = $ca->issueCertificate(countryName => "EU",
#				     commonName => 'ejhernandez@warp.es',
#				     keyPassword => "aaaa",
#				     caKeyPassword => "oooh");
#print "done\n";
#
#print "\nIssue User Certificate...";
#my $userCert = $ca->issueCertificate(stateName   => "Caiman Island",
#				     commonName  => 'jamor@warp.es',
#				     keyPassword => "bbbb",
#				     caKeyPassword => "oooh");
#print "done\n";
##
#print "\nRevoke User Certificate...";
#my $revCert = $ca->revokeCertificate(commonName => 'ejhernandez@warp.es',
#				     reason => 'unspecified',
#				     caKeyPassword => 'oooh',
#				    );
#print "done\n";
#
my $refList = $ca->listCertificates();

foreach my $element (@{$refList}) {

  print "--------------------------------\n";
  print "State: " . $element->{'state'} . "\n";
  print "DN: " . $element->{'dn'}->stringOpenSSLStyle() . "\n";
  # Match to valid and expired certificates
  if ($element->{state} =~ m/[VE]/ ) {
    printf("Expiry Date: %04d-%02d-%02d\n", $element->{'expiryDate'}->{'year'},
	   $element->{'expiryDate'}->{'month'},
	   $element->{'expiryDate'}->{'day'});
  } elsif ($element->{state} eq 'R') {
    printf("Revokation Date: %04d-%02d-%02d\n", $element->{'revokeDate'}->{'year'},
	   $element->{'revokeDate'}->{'month'},
	   $element->{'revokeDate'}->{'day'});
    print "Reason: $element->{reason}\n";
  }

}

#my $refKeys = $ca->getKeys('jamor@warp.es');
#
#print "\nPrinting keys in PEM format...\n";
#printFile($refKeys->{'privateKey'});
#printFile($refKeys->{'publicKey'});
#print "done\n";
#
#print "\nRemove a private Key...";
#$ca->removePrivateKey('jamor@warp.es');
#print "done\n";
#
#print "\nRenew a certificate...";
#my $renewalCert = $ca->renewCertificate(commonName => 'jamor@warp.es',
#				        countryName => 'UK',
#				        keyPassword => 'bbbb',
#				        caKeyPassword => 'oooh');
#printFile($renewalCert);
#print "done";
#
#print "\nUpdating database...";
#$ca->updateDB( caKeyPassword => 'oooh');
#print "done\n";
#
#
