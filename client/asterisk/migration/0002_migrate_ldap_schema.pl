#!/usr/bin/perl

#
# This is a migration script to migrate to the new LDAP schema
#

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Migration::LdapHelpers;
use Error qw(:try);

sub runGConf
{
    my ($self) = @_;

    EBox::Migration::LdapHelpers::updateSchema('asterisk', 'asterisk',
        ['AstAccountVMPassword'],
        {
            'AsteriskVoicemail' => {
                'add' => {
                    'AstContext' => 'users',
                },
                'mod' => {
                    'AstAccountMailbox' => 'AstVoicemailMailbox',
                    'AstAccountVMPassword' => 'AstVoicemailPassword',
                    'AstAccountVMMail' => 'AstVoicemailEmail',
                    'AstAccountVMAttach' => 'AstVoicemailAttach',
                    'AstAccountVMDelete' => 'AstVoicemailDelete',
                }
            },
            'AsteriskSIPUser' => {
                'mod' => {
                    'AstAccountLastms' => 'AstAccountLastQualifyMilliseconds'
                }
            }
        }
    );
}

EBox::init();

my $mod = EBox::Global->modInstance('asterisk');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mod,
        'version' => 2
        );
$migration->execute();
