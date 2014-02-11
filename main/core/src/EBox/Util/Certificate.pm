# Copyright (C) 2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Util::Certificate;

sub generateRSAKey
{
  my ($destDir, $length) = @_;

  my $type    = 'key';
  my ($keyFile, $alreadyExists) = _generateFileInfraestructure($type, $destDir);

  return  ($keyFile, 0)  if   $alreadyExists;

  my @cmds = (
              "openssl genrsa $length > $keyFile",
              "chmod 0400 $keyFile",
             );

  foreach (@cmds) {
    system $_;
    if ($? != 0) {
      die "Generation of RSA key failed";
    }
  }

  return wantarray ? ($keyFile, 1) : $keyFile;
}

sub generateCert
{
  my ($destDir, $keyFile, $keyUpdated, $issuer) = @_;

  my $type = 'crt';
  my ($certFile, $alreadyExists) = _generateFileInfraestructure($type, $destDir, $keyUpdated, 'cert');

  return $certFile if $alreadyExists;

  my $subject;
  if ($issuer) {
      $subject = qq{/CN=$issuer/};
  } else {
      $subject = q{/CN=eBox\ Server/};
  }

  my @cmds = (
              "openssl req -new -x509 -batch -subj $subject  -sha1 -days 3650 -key $keyFile > $certFile",
              "chmod 0400 $certFile",
             );

  foreach (@cmds) {
    system $_;
    if ($? != 0) {
      die "Generation of CERT file failed";
    }
  }


  return $certFile;
}


sub generatePem
{
  my ($destDir, $certFile, $keyFile, $keyUpdated) = @_;

  my $type = 'pem';
  my ($pemFile, $alreadyExists) = _generateFileInfraestructure($type, $destDir, $keyUpdated);

  return $pemFile if $alreadyExists;

  my @cmds = (
              "cat $certFile $keyFile > $pemFile",
              "chmod 0400 $pemFile",
             );

  foreach (@cmds) {
    system $_;
    if ($? != 0) {
      die "Generation of PEM file failed";
    }
  }

  return $pemFile;

}


sub _generateFileInfraestructure
{
  my ($type, $destDir, $alwaysDelete, $extension) = @_;
  defined $alwaysDelete or $alwaysDelete = 0;
  $extension            or $extension    = $type;

  my $sslDir  = _sslDir($destDir, $type);
  my $file     = "$sslDir/ssl.$extension";

  if (-e $file) {
    # "$file already exists. Skipping generation\n";
    return ($file, 1);
  }

  my  @cmds =  (
                "touch $file",
                 "chmod 0600 $file",
                 );


  foreach (@cmds) {
    system $_;
    if ($? != 0) {
      die "Generation of $type file failed";
    }
  }

  return ($file, 0);
}

sub _sslDir
{
  my ($destDir, $postfix) = @_;

  my $sslDir = "$destDir";
  if (not -d $sslDir) {
      mkdir $sslDir, 0700;
  }

  return $sslDir;
}

sub getCertIssuer
{
    my ($self, $certFile) = @_;
    my $cmd = "openssl x509 -in $certFile -issuer -noout";
    my $output;
    try {
        $output = EBox::Sudo::root($cmd);
    } otherwise {
        $output = undef;
    };
    if (not $output) {
        return undef;
    }

    # example output: issuer= /CN=z32a.zentyal-domain.lan
    my $line = $output->[0];
    chomp $line;
    my ($attr, $type, $value) = split '=', $line;
    if (($type =~ m{\s*/CN}) and $value) {
        return $value;
    }
    return undef;
}

1;
