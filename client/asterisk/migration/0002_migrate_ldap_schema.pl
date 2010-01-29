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

use EBox::Asterisk::Extensions;

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
                'add' => {
                    'AstAccountDTMFMode' => 'rfc2833',
                    'AstAccountInsecure' => 'port',
                },
                'mod' => {
                    'AstAccountLastms' => 'AstAccountLastQualifyMilliseconds'
                }
            }
        }
    );

    my $extensions = new EBox::Asterisk::Extensions;
    $extensions->{ldap}->ldapCon;
    my $ldap = $extensions->{ldap}->{ldap};

    my @extns = $extensions->extensions;
    foreach (@extns) {
        $extensions->delExtension($_);
    }

    my $users = EBox::Global->modInstance('users');

    my %args = (
                base => $users->usersDn,
                filter => 'objectclass=AsteriskSIPUser',
                scope => 'one'
               );
    my $result = $ldap->search(%args);
    foreach my $entry ($result->entries()) {
        my $user = $entry->get_value('uid');
        my $extn = $entry->get_value('AstAccountCallerID');
        my %attrs = (changes => [
                                 add => [
                                         objectClass => 'AsteriskQueueMember',
                                         AstQueueMembername => $user,
                                         AstQueueInterface => "SIP/$user"
                                        ],
                                ]
                    );
        my $dn = $users->userDn($user);
        $ldap->modify($dn, %attrs);
        $extensions->addUserExtension($user, $extn);
    }

    my $qdn = $extensions->queuesDn;
    $ldap->add($qdn, attr => [
                         'ou' => 'Queues',
                         'objectClass' => 'top',
                         'objectClass' => 'organizationalUnit'
	                     ]);
}

EBox::init();

my $mod = EBox::Global->modInstance('asterisk');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mod,
        'version' => 2
        );
$migration->execute();
