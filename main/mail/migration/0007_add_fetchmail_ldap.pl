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
            # fetchmail schema is present, nothing to do
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
