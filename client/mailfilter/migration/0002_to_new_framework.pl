#!/usr/bin/perl

#  Migration between gconf data versions
#

use strict;
use warnings;

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::MailFilter::VDomainsLdap;

use Error qw(:try);
use Perl6::Junction qw(all);
use File::Basename;

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

    my $mailfilter = $self->{gconfmodule};

    my $generalModelExists = $self->_modelExists('General');

    if ($generalModelExists) {
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
    } else {
        # we will put the keys in General-like dir so 0005_migrate_old_keys
        # could pick them i nthe same place
        $self->_migrateKey(
                           oldKey => 'port',
                           newKey => 'General/port',
                           type  => 'int',
                          );

        my $admin_address = $mailfilter->get_string('admin_address');
        if ($admin_address) {
            $mailfilter->set_string('General/notification_selected', 'address');
            $self->_migrateKey(
                               oldKey => 'admin_address',
                               newKey => 'General/address',
                               type  => 'string',
                              );
        } else {
            $mailfilter->set_string('General/notification_selected', 'disabled')
        }

        $mailfilter->unset('admin_address');
    }
}


sub _migrateToBadHeadersPolicy
{
    my ($self) = @_;
    $self->_migratePolicy('BadHeadersPolicy', 'bhead_policy');
}

sub _migrateToBannedFilesPolicy
{
    my ($self) = @_;
   $self->_migratePolicy('BannedFilesPolicy', 'banned_policy');
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

    my $modelExists = $self->_modelExists('AntivirusConfiguration');

    if ($modelExists) {
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
  } else {
      $self->_migrateKey(
                         oldKey => 'clamav/active',
                         newKey => 'AntivirusConfiguration/enabled',
                         type  => 'bool',
                        );
      $self->_migratePolicy('AntivirusConfiguration', 'virus_policy');
  }
}

sub _migrateToAntispamConfiguration
{
    my ($self) = @_;

    $self->_migrateToForm(
                          'AntispamConfiguration',

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

    # spam policy and enabled has been removed from new version of AntiVirus
    # model so we put it manually in place
     $self->_migrateKey(
                         oldKey => 'spam_policy',
                         newKey => 'AntispamConfiguration/policy',
                         type   => 'string',
                        );

     $self->_migrateKey(
                         oldKey => 'spamassasin/active',
                         newKey => 'AntispamConfiguration/enabled',
                         type   => 'bool',
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
        if ($list->findRow($elementName => $element)) {
            next;
        }

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

        if ($table->findRow($elementName => $element)) {
            next;
        }

        $table->addRow(
                       $elementName => $element,
                       allow        => $allow,
                      )
    }

    $module->delete_dir($directory);
}




sub _modelExists
{
    my ($self, $model) = @_;
    my $mailfilter = $self->{gconfmodule};

    my $modelExists;
    try {
        $mailfilter->model($model);
        $modelExists = 1;
    } catch EBox::Exceptions::Internal with {
        $modelExists = 0;
    };

    return $modelExists;
}


sub _migratePolicy
{
    my ($self, $model, $oldPolicyName) = @_;

    my $modelExists = $self->_modelExists($model);


    if ($modelExists) {
      $self->_migrateToForm(
                          $model,
                          $oldPolicyName => {
                                   keyGetter => 'get_string',
                                   formElement => 'policy',
                                  },
                         );
  } else {
      $self->_migrateKey(
                         oldKey => $oldPolicyName,
                         newKey => "$model/policy",
                         type   => 'string',
                        );
  }

}



sub _migrateKey
{
    my ($self, %args) = @_;
    my $newKey = $args{newKey};
    my $oldKey = $args{oldKey};
    my $type   = $args{type};
    defined $newKey or die;
    defined $oldKey or die;
    defined $type   or die;

    my $getter = "get_$type";
    my $setter = "set_$type";


    my $module = $self->{gconfmodule};


    $self->_migrateSimpleKeys(
                              $module,
                              {
                               $oldKey => {
                                           newKey => $newKey,
                                           getter => $getter,
                                           setter => $setter
                                          },

                              }

                             );
}


sub _migrateSimpleKeys
{
  my ($self, $mod, $deprecatedKeys_r) = @_;

  my %allExistentKeysByDir = ();


  while (my ($oldKey, $migrationSpec) = each %{ $deprecatedKeys_r }) {
      my $dir;
      if ($oldKey =~ m{/}) {
          $dir = dirname($oldKey);
      }
      else {
          $dir = '';
      }

      if (not exists $allExistentKeysByDir{$dir}) {
          my @entries = map {
              if ($dir) {
                  $dir . '/' . $_
              } else {
                  $_
              }

           }  @{ $mod->all_entries_base($dir) };

          $allExistentKeysByDir{$dir} = all (@entries );
      }

      my $allExistentKeys = $allExistentKeysByDir{$dir};
      if ( $oldKey ne $allExistentKeys ) {
          next;
      }




      my $newKey = $migrationSpec->{newKey};
      my $getter = $migrationSpec->{getter};
      my $setter = $migrationSpec->{setter};


      my $oldValue  = $mod->$getter($oldKey);
      $mod->$setter($newKey, $oldValue);

      $mod->unset($oldKey);
  }
}



EBox::init();
my $mailfilter = EBox::Global->modInstance('mailfilter');
my $migration = new EBox::Migration(
                                     'gconfmodule' => $mailfilter,
                                     'version' => 2
                                    );
$migration->execute();


1;
