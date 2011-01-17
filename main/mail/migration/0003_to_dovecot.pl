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

# This is a migration script to add a service and firewall rules
# for the Zentyal mail system
#
# For next releases we should be able to enable/disable some ports
# depening on if certain mail service is enabled or not
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;

use EBox::MailVDomainsLdap;

use Error qw(:try);

use constant DIR_VMAIL   =>      '/var/vmail/';

sub runGConf
{
    my ($self) = @_;
    $self->_dovecotMigration();
    $self->_retrievalServicesMigration();
    $self->_mailboxesMigration();
}

sub _dovecotMigration
{
    my ($self) = @_;
    my $mail = $self->{gconfmodule};

    if (not $mail->configured()) {
        # when conifugred , odvecot files will be put in place
        return;
    }

    # postfix do not longer need of membership of the sasl group
    my ($name,$passwd,$gid,$members) = getgrnam('sasl');
    my $postfixIsMember;
    if (defined $members) {
        $postfixIsMember  = grep {
            $_ eq 'postfix'
        } split '\s', $members;
    }

    if ($postfixIsMember) {
        EBox::Sudo::root("deluser postfix sasl");
    }

    # we will create the new certificates for dovecot
    # we donot use the old ones  from courier bz
    #   courier used two distinct certificates for pops and imaps

    EBox::Sudo::root(EBox::Config::share() . '/zentyal-mail/ebox-mail-enable gen-dovecot-cert');
}


sub _retrievalServicesMigration
{
    my ($self) = @_;
    my $mail = $self->{gconfmodule};

    my $dir       = 'RetrievalServices';
    my $oldPopKey= "$dir/pop3";
    my $oldImapKey= "$dir/imap";
    my $oldTlsKey= "$dir/ssl";

    my $entriesChanged = grep {
        ($_ eq $oldPopKey ) or
        ($_ eq $oldImapKey ) or
        ($_ eq $oldTlsKey )
    }  $mail->all_entries($dir) ;

    if ($entriesChanged) {
        return;
    }

    # get the old values and delete it form gconf
    my $oldPopValue   = $mail->get_bool($oldPopKey);
    my $oldImapValue  = $mail->get_bool($oldImapKey);
    my $oldTlsValue   = $mail->get_string($oldTlsKey);
    $mail->unset($oldPopKey);
    $mail->unset($oldImapKey);
    $mail->unset($oldTlsKey);


    my $tls   = 0;
    my $noTls = 0;
    if ((defined $oldTlsValue) and ($oldTlsValue eq 'required')) {
        $tls = 1;
    }
    elsif ((defined $oldTlsValue) and($oldTlsValue eq 'optional')) {
        $tls = 1;
        $noTls = 1;
    }
    else {
        $noTls = 1;
    }


    my $popKey = "$dir/pop3";
    my $popsKey= "$dir/pop3s";
    my $imapKey= "$dir/imap";
    my $imapsKey= "$dir/imaps";

    if ($oldPopValue and $noTls) {
        $mail->set_bool($popKey, 1);
    }
    if ($oldPopValue and $tls) {
        $mail->set_bool($popsKey, 1);
    }
    if ($oldImapValue and $noTls) {
        $mail->set_bool($imapKey, 1);
    }
    if ($oldImapValue and $tls) {
        $mail->set_bool($imapsKey, 1);
    }
}


sub _mailboxesMigration
{
    my ($self) = @_;
    my $mail = $self->{gconfmodule};
    my $script  = EBox::Config::share() . '/ebox-mail/courier-dovecot-migrate.pl';
    my $dir = DIR_VMAIL;;

    my $cmd = "$script --convert --to-dovecot --recursive $dir";
    EBox::Sudo::root($cmd);
}

EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 3
        );
$migration->execute();
