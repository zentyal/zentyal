#!/usr/bin/perl
#
# Th
#
package EBox::Migration;
use base 'EBox::MigrationBase';

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
