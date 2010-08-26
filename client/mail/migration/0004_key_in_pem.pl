#!/usr/bin/perl
#
# Copyright (C) 2008-2010 eBox Technologies S.L.
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

# Th
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Config;
use File::Slurp;

use Error qw(:try);

use constant DOVECOT_PEM_PATH => '/etc/dovecot/ssl/dovecot.pem';
use constant DOVECOT_KEY_PATH => '/etc/dovecot/ssl/dovecot_key.pem';

use constant POSTFIX_PEM   => '/etc/postfix/sasl/postfix.pem';
use constant POSTFIX_CERT  => '/etc/postfix/sasl/smtpd.pem';
use constant POSTFIX_KEY   => '/etc/postfix/sasl/smtpd-key.pem';

sub runGConf
{
    my ($self) = @_;

    $self->_toKeyInPem(POSTFIX_PEM, POSTFIX_CERT, POSTFIX_KEY);
    $self->_toKeyInPem(DOVECOT_PEM_PATH, DOVECOT_PEM_PATH, DOVECOT_KEY_PATH);
}

sub _toKeyInPem
{
    my ($self, $pemFile, $certFile, $keyFile) = @_;

    # if not key file exists we haven't to do anything
    if (not EBox::Sudo::fileTest('-e', $keyFile)) {
        return;
    }

    my $tmpFile = EBox::Config::tmp() . 'keyinpem.tmp';
    my $certAndKey=   EBox::Sudo::root("cat $certFile $keyFile") ;
    my $oldUmask = umask();
    umask('0007');
    try {
        File::Slurp::write_file($tmpFile, $certAndKey);
    } finally {
        umask $oldUmask;
    };

    EBox::Sudo::root("chown root:root $tmpFile");
    EBox::Sudo::root("chmod 0400 $tmpFile");
    EBox::Sudo::root("mv $tmpFile $pemFile");
    EBox::Sudo::root("rm $keyFile");
}



EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 4,
        );
$migration->execute();
