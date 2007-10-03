package EBox::Squid::Test;
use base 'EBox::Test::Class';
#
use strict;
use warnings;

use Test::More;
use Test::Exception;


use lib '../..';

use EBox::TestStubs;
use EBox::Squid;



sub serviceTest : Test(15)
{
  my ($self) = @_;

  my $squid = EBox::Squid->_create();

  my $serviceModel =  'SquidService';
  my $serviceAttr  =  'enabled';
  

  foreach my $state (0, 1, 1, 0, 0 ) {
    lives_ok {  $squid->setService($state) } 'Checking setService method';
    is $squid->service, $state, 'Checking wether the service atribute has been changed';
    _checkModelAttribute($squid, $serviceModel, $serviceAttr, $state, 'checking wether the value ihas changed in the method')
  }

}


sub _checkModelAttribute
{
  my ($squid, $model, $attr, $expectedValue, $msg) = @_;
  defined $msg or
    $msg = "Checking attribute $attr of model $model";

  my $mInstance = $squid->model($model);
  my $attrGetter = $attr . 'Value';
  is $mInstance->$attrGetter, $expectedValue, $msg;
}


# sub allowedMimeTypesTest : Test(4)
# {
#   my $squid = EBox::Squid->_create();

#   # setting mime types
#   EBox::TestStubs::setConfig(
# 			     '/ebox/modules/squid/allowed_mimetype' => [qw(
#                                             text/html
#                                             application/pgp-signature
#                                             application/mbox
# 								       )],
# 			     '/ebox/modules/squid/banned_mimetype'  => [qw(
#                                            application/msword
#                                            video/mpeg
#                                            video/raw
#                                            video/vc1
# 								       )],
# 			    );

#   # Controlling allowed
#   my $allowed = $squid->allowedMimeTypes();
#   my $oldN = scalar (@{$allowed});
  
#   #print "Allowed mime types: " . @{$allowed} . $/;
  
#   my $mimeType = "application/octet-stream";
  
#   push ( @{$allowed}, $mimeType );
  
#   #print @{$allowed};
  
#   $squid->setAllowedMimeTypes(@{$allowed});
  
#   $allowed = $squid->allowedMimeTypes();
#   my $n = scalar (@{$allowed});
  
#   # 3
#   cmp_ok ( $n, "==", $oldN + 1, 'allowed mime type added');
  
#   # Restoring old values
#   @{$allowed} = grep {!/application\/octet-stream/} @{$allowed};
#   $squid->setAllowedMimeTypes(@{$allowed});
  
#   # Controlling banned
#   my $banned = $squid->bannedMimeTypes();
#   $oldN = scalar (@{$banned});
  
#   $mimeType = "image/pipeg";
  
#   push ( @{$banned}, $mimeType );
  
#   $squid->setBannedMimeTypes(@{$banned});
  
#   $banned = $squid->bannedMimeTypes();
#   $n = scalar (@{$banned});
  
#   # 4
#   cmp_ok ( $n, "==", $oldN + 1, 'banned mime type added');
  
#   # Restoring old values
#   @{$banned} = grep {!/image\/pipeg/} @{$banned};
#   $squid->setBannedMimeTypes(@{$banned});
  
#   # Compare with hashed
#   my $hashed = $squid->hashedMimeTypes();
#   my ($cAllowed, $cBanned ) = (0, 0);
#   while ( my ($key, $value) = each %{$hashed} ) {
#     # Do you like perl conditional commands? XD
#     $cAllowed++ if ($value);
#     $cBanned++  unless ($value);
#   }
  
#   cmp_ok ( $cAllowed, "==", scalar(@{$allowed}), 'All allowed mime types remain the same');
#   cmp_ok ( $cBanned, "==", scalar(@{$banned}), 'All allowed mime types remain the same');
# }  

1;
