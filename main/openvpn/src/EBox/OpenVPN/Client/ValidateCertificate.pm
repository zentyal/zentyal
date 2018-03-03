# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::OpenVPN::Client::ValidateCertificate;

use EBox::Sudo qw(root);
use EBox::Config;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Gettext;

use TryCatch;
use File::Temp qw(tempfile);
use File::Slurp qw(write_file);

use constant OPENSSL_PATH => '/usr/bin/openssl';
use constant DIFF_PATH    => '/usr/bin/diff';

sub check
{
    my ($caPath, $certPath, $privKeyPath) = @_;
    defined $caPath or
        throw EBox::Exceptions::MissingArgument('caPath');
    defined $certPath or
        throw EBox::Exceptions::MissingArgument('certPath');
    defined $privKeyPath or
        throw EBox::Exceptions::MissingArgument('privKeyPath');

    EBox::Sudo::fileTest('-f', $caPath) or
        throw EBox::Exceptions::External(__x("Inexistent CA's certificate file {p}", p => $caPath));

    EBox::Sudo::fileTest('-f', $certPath) or
        throw EBox::Exceptions::External(__x("Inexistent client's certificate file {p}", p => $certPath));

    EBox::Sudo::fileTest('-f', $privKeyPath) or
        throw EBox::Exceptions::External(__x("Inexistent certificate's private key file {p}", p => $privKeyPath));

    _verifyCaCert($caPath);
    _verifyCert($certPath);
    _verifyPrivKey($privKeyPath);

    _verifyCertWithCa($certPath, $caPath);
    _verifyCertWithPrivKey($certPath, $privKeyPath);
}

sub _verifyCaCert
{
    my ($caPath) = @_;
    my $verifyOk = _opensslVerify($caPath);

    unless ($verifyOk) {
        throw EBox::Exceptions::External(__(q{File supplied as CA's certificate is not valid}));
    }
}

sub _verifyCert
{
    my ($certPath) = @_;

    my $cmd =  OPENSSL_PATH . " x509 -noout -in '$certPath'";
    try {
        EBox::Sudo::root($cmd);
    } catch {
        throw EBox::Exceptions::External(__(q{File supplied as client's certificate is not valid}));
    }
}

sub _verifyPrivKey {
    my ($privKeyPath) = @_;

    my $cmd = OPENSSL_PATH . " rsa -noout -in '$privKeyPath'";
    try {
        EBox::Sudo::root($cmd);
    } catch {
        throw EBox::Exceptions::External(__(q{File supplied as client's private key is not valid}));
    }
}

sub  _verifyCertWithCa
{
    my($certPath, $caPath) = @_;
    my $verifyParams = " -CAfile '$caPath' '$certPath'";

    my $verifyOk = _opensslVerify($verifyParams);
    unless ($verifyOk) {
        throw EBox::Exceptions::External(
                __(q{File supplied as client's certificate doesn't match with file supplied as CA's certificate})
        );
    }
}

sub _verifyCertWithPrivKey
{
    my ($certPath, $privKeyPath) = @_;

    # prepare files
    my ($fhPubCert, $pubCert) = tempfile(DIR => EBox::Config::tmp);
    my ($fhPubKey, $pubKey) = tempfile(DIR => EBox::Config::tmp);

    # XXX check of race condition!!

    my $certCmd = OPENSSL_PATH . " x509 -pubkey -noout -in '$certPath'";
    my $certOutput = EBox::Sudo::root( $certCmd );
    write_file($fhPubCert, $certOutput);

    my $keyCmd = OPENSSL_PATH . " rsa -pubout -in '$privKeyPath'";
    my $keyOutput = EBox::Sudo::root( $keyCmd );
    write_file($fhPubKey, $keyOutput);

    try {
        my $diffCmd = DIFF_PATH . " --brief '$pubCert' '$pubKey'";
        EBox::Sudo::root($diffCmd);
    } catch {
        throw EBox::Exceptions::External(
                __(q{File supplied as client's certificate doesn't match with file supplied as certificate's private key})
        );
    }
}

sub _opensslVerify
{
    my (@params) = @_;
    my $cmd =  OPENSSL_PATH . ' verify ' . "@params";

    my $output_r = EBox::Sudo::root($cmd);

    my $lastLine = $output_r->[-1];
    defined $lastLine or return 0;

    my $okFound = $lastLine =~ m{
        (^|\s)
        OK
        (^|\s)
    }xm;

    return $okFound;
}

1;
