#!/usr/bin/perl
#
# This is a migration script to add the LDAP data for fetchmail feature
#
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::Sudo;

sub runGConf
{
    my ($self) = @_;

    my $mail = $self->{gconfmodule};
    if (not $mail->configured()) {
        return;
    }

    $self->_updateSchemas();
    $self->_updateData();

    
}

sub _updateSchemas
{
    my ($self) = @_;
    my $ldapCat = q{slapcat -bcn=config };
    my @output = EBox::Sudo::root($ldapCat);
    foreach my $line (@output) {
        if ($line =~ m{cn=\{\d+\}eboxfetchmail,cn=schema,cn=config}) {
            # fetchamil schema is present, nothing to do
            return;            
        }
    }

    my $mail = $self->{gconfmodule};
    # is assumed that performLDAP actions is idempotent!
    $mail->performLDAPActions();
}


sub _updateData
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');
    my $ldap  = $users->ldap();

    my %args = (
                 base => $users->usersDn,
                 filter => 'objectclass=usereboxmail',
                 scope => 'sub'
                ); 

    my $result = $ldap->search(\%args);
    foreach my $entry ($result->entries()) {
        my $hasFetchmailClass = grep {
            my $class = lc $_;
            $class eq 'fetchmailuser'
        } $entry->get_value('objectClass');

        $hasFetchmailClass and
            next;

        $entry->add(objectClass => 'fetchmailUser');
        $entry->update($ldap->ldapCon());
    }

}


EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 7,
        );
$migration->execute();
