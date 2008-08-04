#!/usr/bin/perl

#  Migration between gconf data versions
#

use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::MailFilter::VDomainsLdap;


sub runGConf
{
  my ($self) = @_;

  $self->_migrateToGeneral();

  $self->_migrateToExternalMTA();
  $self->_migrateToExternalDomain();
      

  $self->_migrateToBadHeadersPolicy();
  $self->_migrateToBannedFilesPolicy();

  $self->_migrateToMIMETypeACL();
  $self->_migrateToFileExtensionsACL();

  $self->_migrateToAntivirusConfiguration();

  $self->_migrateToAntispamConfiguration();
  $self->_migrateToAntispamACL();
  $self->_migrateLearnAccounts();

  $self->_removeLeftoverKeys();
}



sub _migrateToGeneral
{
    my ($self) = @_;

    $self->_migrateToForm(
                          'General',
                          port => {
                                   keyGetter => 'get_int',
                                   formElement => 'port',
                                  },
                          'admin_address'    => {
                                                 keyGetter => 'get_string',
                                                 formElement => 'notification',
                                                 adapter => sub {
                                                     my ($addr) = @_;
                                                     if (not $addr) {
                                                         return { disabled => ''} ;
                                                     }
                                                     return { address=> $addr }
                                                 }           
                                                },
                         );
}


sub _migrateToBadHeadersPolicy
{
    my ($self) = @_;

    $self->_migrateToForm(
                          'BadHeadersPolicy',
                          'bhead_policy' => {
                                   keyGetter => 'get_string',
                                   formElement => 'policy',
                                  },
                         );

}

sub _migrateToBannedFilesPolicy
{
    my ($self) = @_;

    $self->_migrateToForm(
                          'BannedFilesPolicy',
                          'banned_policy' => {
                                   keyGetter => 'get_string',
                                   formElement => 'policy',
                                  },
                         );

}


sub _migrateToMIMETypeACL
{
    my ($self) = @_;
    $self->_migrateToAllowTable(
                                'MIMETypeACL',
                                elementName => 'MIMEType',
                                directory   => 'file_filter/mime_types',
                                adapter =>  sub {
                                    my ($mimeType) = @_;
                                    $mimeType =~ s{_}{/};
                                    return $mimeType;
                                },
                               );
}


sub _migrateToFileExtensionsACL
{
    my ($self) = @_;
    $self->_migrateToAllowTable(
                                'FileExtensionACL',
                                elementName => 'extension',
                                directory   => 'file_filter/extensions',
                               );
}


sub _migrateToExternalMTA
{
    my ($self) = @_;  
    $self->_migrateToExternalConnectionsList(
                          'ExternalMTA',
                          key => 'allowed_external_mtas',
                          elementName => 'mta',
                         );

}


sub _migrateToExternalDomain
{ 
    my ($self) = @_;  
    $self->_migrateToExternalConnectionsList(
                          'ExternalDomain',
                          key => 'external_domains',
                          elementName => 'domain',
                         );
}


sub _migrateToAntivirusConfiguration
{
    my ($self) = @_;   

    $self->_migrateToForm(
                          'AntivirusConfiguration',
                          'clamav/active' => {
                                   keyGetter => 'get_bool',
                                   formElement => 'enabled',
                                  },
                          'virus_policy' => {
                                   keyGetter => 'get_string',
                                   formElement => 'policy',
                                  },
                         );
}

sub _migrateToAntispamConfiguration 
{
    my ($self) = @_;  

    $self->_migrateToForm(
                          'AntispamConfiguration',
                          'spamassassin/active' => {
                                   keyGetter => 'get_bool',
                                   formElement => 'enabled',
                                  },
                          'spam_policy' => {
                                   keyGetter => 'get_string',
                                   formElement => 'policy',
                                  },
                          'spamassassin/spam_threshold' => {
                                  keyGetter => 'get_string',
                                  formElement => 'spamThreshold',
                                                           },
                          'spamassassin/spam_subject_tag' => {
                                  keyGetter => 'get_string',
                                  formElement => 'spamSubjectTag',
                                                           },
                          'spamassassin/bayes' => {
                                  keyGetter => 'get_bool',
                                  formElement => 'bayes',
                                                  },
                          'spamassassin/autowhitelist' => {
                                  keyGetter => 'get_bool',
                                  formElement => 'autoWhitelist',
                                                  },
                          'spamassassin/autolearn' => {
                                  keyGetter => 'get_bool',
                                  formElement => 'autolearn',
                                                  },
                          'spamassassin/autolearn_spam_threshold' => {
                                  keyGetter => 'get_string',
                                  formElement => 'autolearnSpamThreshold',
                                                  },
                          'spamassassin/autolearn_ham_threshold' => {
                                  keyGetter => 'get_string',
                                  formElement => 'autolearnHamThreshold',
                                                  },
                         );
}


sub _migrateToAntispamACL 
{
    my ($self) = @_;   
    my $mailf = $self->{gconfmodule};
    my $acl = $mailf->model('AntispamACL');
    

    my @whitelist = @{ $mailf->get_list('spamassassin/whitelist') };
    foreach my $sender (@whitelist) {
        $acl->addRow(
                     sender => $sender,
                     policy => 'whitelist',
                    )
    }

    
    my @blacklist = @{ $mailf->get_list('spamassassin/blacklist') };
    foreach my $sender (@blacklist) {
        $acl->addRow(
                     sender => $sender,
                     policy => 'blacklist',
                    )
    }

    $mailf->unset('spamassassin/whitelist');
    $mailf->unset('spamassassin/blacklist');
}



sub _migrateLearnAccounts
{
    my ($self) = @_;   
    my $mailf = $self->{gconfmodule};
    $mailf->configured() or
        return;

    my $vdomainsLdap = EBox::MailFilter::VDomainsLdap->new();

    my $spamAccount = $mailf->get_bool('spamassassin/spam_account_active');
    my $hamAccount  = $mailf->get_bool('spamassassin/ham_account_active');

    my @vdomains = $vdomainsLdap->vdomains();
    foreach my $vdomain (@vdomains) {
        $vdomainsLdap->setSpamAccount($vdomain, $spamAccount);
        $vdomainsLdap->setHamAccount($vdomain, $hamAccount);

    }

    $mailf->unset('spamassassin/spam_account_active');
    $mailf->unset('spamassassin/ham_account_active');
}

sub _removeLeftoverKeys
{
    my ($self) = @_;
    my $mailf = $self->{gconfmodule};

    my @keys = qw(
                  file_filter/holder
                 );

    foreach my $key (@keys) {
        $mailf->unset($key);
    }

}

sub _migrateToForm
{
    my ($self, $formName, %migrate) = @_;
    my $mail = $self->{gconfmodule};
    my $form = $mail->model($formName);
    
    my $row = $form->row();

    my $changed = 0;
    while (my ($oldKey, $migrationSpec) = each %migrate) {
        my $keyGetter   = $migrationSpec->{keyGetter};
        my $formElement = $migrationSpec->{formElement};

        my $value = $mail->$keyGetter($oldKey);
        if (not defined $value) {
            next;
        }

        # zero may be the equivalent of undefined value for ints
        if ($keyGetter eq 'get_int') {
            if ($value == 0 and not $migrate{alowZero}) {
                next;
            }
        }
        elsif (not $value) {
            next;
        }


        if (exists $migrationSpec->{adapter}) {
            $value = $migrationSpec->{adapter}->($value);
        }


        my $element = $row->elementByName($formElement);
        $element->setValue($value);
        $changed = 1;
    }

    if ($changed) {
        $row->store();
    }


    # remove old keys
    foreach my $oldKey (keys %migrate) {
        $mail->unset($oldKey);
    }

}


sub _migrateToExternalConnectionsList
{
    my ($self, $listName, %params) = @_;
    my $module = $self->{gconfmodule};
    my $list = $module->model($listName);

    my $key         = $params{key};
    my $elementName = $params{elementName};

    my @contents = @{  $module->get_list($key) };
    foreach my $element (@contents) {
                $list->addRow(
                               $elementName => $element,
                               allow => 1,
                              )
    }

}


sub _migrateToAllowTable
{
    my ($self, $tableName, %params) = @_;
    my $module = $self->{gconfmodule};
    my $table = $module->model($tableName);

    my $directory   = $params{directory};
    my $elementName = $params{elementName};
    my $adapter     = $params{adapter};

    my $hashFromDir = $module->hash_from_dir($directory);
    while (my ($element, $allow) = each %{ $hashFromDir }) {
        if ($adapter) {
            $element = $adapter->($element);
        }

        $table->addRow(
                       $elementName => $element,
                       allow        => $allow,
                      )
    }

    $module->delete_dir($directory);
}


EBox::init();
my $mailfilter = EBox::Global->modInstance('mailfilter');
my $migration = new EBox::Migration( 
                                     'gconfmodule' => $mailfilter,
                                     'version' => 2
                                    );
$migration->execute();                               


1;
