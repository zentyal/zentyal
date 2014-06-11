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

package EBox::Samba::SmbClient;
use base 'Samba::Smb';

use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Samba::AuthKrbHelper;

use TryCatch::Lite;
use Fcntl qw(O_RDONLY O_CREAT O_TRUNC O_RDWR);
use Samba::Credentials;
use Samba::LoadParm;
use Samba::Security::Descriptor;
use Samba::Smb qw(NTCREATEX_DISP_OVERWRITE_IF NTCREATEX_DISP_OPEN FILE_ATTRIBUTE_NORMAL);

sub new
{
    my ($class, %params) = @_;

    my $target = delete $params{target};
    unless (defined $target) {
        throw EBox::Exceptions::MissingArgument('target');
    }

    my $service = delete $params{service};
    unless (defined $service) {
        throw EBox::Exceptions::MissingArgument('service');
    }

    my $krbHelper = new EBox::Samba::AuthKrbHelper(%params);

    my $lp = new Samba::LoadParm();
    $lp->load_default();

    my $creds = new Samba::Credentials($lp);
    $creds->kerberos_state(CRED_MUST_USE_KERBEROS);
    $creds->guess();

    my $self = $class->SUPER::new($lp, $creds);
    my $ok = 0;
    my $maxTries = 10;
    for (my $try = 1; ($try <= $maxTries) and (not $ok); $try++) {
        try {
            $self->connect($target, $service);
            $ok = 1;
            if ($try > 1) {
                EBox::info("Connection to Samba SMB successful after $try tries.");
            }
        } catch ($e) {
            EBox::warn("Error connecting with SMB server: $e, retrying ($try attempts)");
            sleep 1;
        }
    }
    if (not $ok) {
        throw EBox::Exceptions::External("Error connecting with SMB server after $maxTries tries.");
    }

    $self->{krbHelper} = $krbHelper;
    $self->{loadparm} = $lp;
    $self->{credentials} = $creds;

    bless ($self, $class);
    return $self;
}

sub read_file
{
    my ($self, $path) = @_;

    unless ($self->chkpath($path)) {
        throw EBox::Exceptions::External("chkpath: Failed. File does not exists.");
    }

    # Open file and get the size
    my $finfo = $self->getattr($path);
    my $fileSize = $finfo->{size};

    my $openParams = {
        open_disposition => NTCREATEX_DISP_OPEN,
        file_attr => $finfo->{mode},
        access_mask => SEC_RIGHTS_FILE_READ,
    };
    my $fd = $self->open($path, $openParams);

    # Read to buffer
    my $buffer;
    my $chunkSize = 4096;
    my $pendingBytes = $fileSize;
    my $readBytes = 0;
    while ($pendingBytes > 0) {
        my $tmpBuffer;
        $chunkSize = ($pendingBytes < $chunkSize) ?
                      $pendingBytes : $chunkSize;
        my $nRead = $self->read($fd, $tmpBuffer, $readBytes, $chunkSize);
        $buffer .= $tmpBuffer;
        $readBytes += $nRead;
        $pendingBytes -= $nRead;
    }

    # Close and return buffer
    $self->close($fd);

    return $buffer;
}

sub write_file
{
    my ($self, $dst, $buffer) = @_;

    my $openParams = {
        open_disposition => NTCREATEX_DISP_OVERWRITE_IF,
        access_mask => SEC_RIGHTS_FILE_ALL,
        file_attr => FILE_ATTRIBUTE_NORMAL,
    };
    if ($self->chkpath($dst)) {
        my $finfo = $self->getattr($dst);
        $openParams->{file_attr} = $finfo->{mode},
    }

    my $fd = $self->open($dst, $openParams);
    my $size = length ($buffer);
    my $wrote = $self->write($fd, $buffer, $size);
    if ($wrote == -1) {
        throw EBox::Exceptions::Internal(
            "Can not write $dst: $!");
    }
    $self->close($fd);

    unless ($wrote == $size) {
        throw EBox::Exceptions::Internal(
            "Error writting to $dst. Sizes does not match");
    }
}

sub copy_file_to_smb
{
    my ($self, $src, $dst) = @_;

    my @srcStat = stat ($src);
    unless ($#srcStat) {
        throw EBox::Exceptions::Internal("Can not stat $src");
    }
    my $srcSize = $srcStat[7];
    my $pendingBytes = $srcSize;
    my $writtenBytes = 0;

    my $openParams = {
        open_disposition => NTCREATEX_DISP_OVERWRITE_IF,
        access_mask => SEC_RIGHTS_FILE_ALL,
        file_attr => FILE_ATTRIBUTE_NORMAL,
    };
    if ($self->chkpath($dst)) {
        my $finfo = $self->getattr($dst);
        $openParams->{file_attr} = $finfo->{mode},
    }
    my $fd = $self->open($dst, $openParams);
    my $ret = open(SRC, $src);
    if ($ret == 0) {
        throw EBox::Exceptions::Internal("Can not open $src: $!");
    }

    my $buffer = undef;
    my $chunkSize = 4096;
    while ($pendingBytes > 0) {
        $chunkSize = ($pendingBytes < $chunkSize) ?
                      $pendingBytes : $chunkSize;
        my $read = sysread (SRC, $buffer, $chunkSize);
        unless (defined $read) {
            throw EBox::Exceptions::Internal("Can not read $src: $!");
        }
        $pendingBytes -= $read;

        my $bufferSize = length($buffer);
        my $wrote = $self->write($fd, $buffer, $bufferSize);
        unless ($wrote == $bufferSize) {
            throw EBox::Exceptions::Internal(
                "Wrote bytes does not match buffer size");
        }
        $writtenBytes += $wrote;
    }
    close SRC;
    $self->close($fd);

    unless ($writtenBytes == $srcSize and $pendingBytes == 0) {
        throw EBox::Exceptions::Internal(
            "Error copying $src to $dst. Sizes does not match");
    }
}

1;
