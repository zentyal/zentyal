#!/usr/bin/perl
#
# This is a migration script to add a service and firewall rules
# for the eBox mail system
#
# For next releases we should be able to enable/disable some ports
# depening on if certain mail service is enabled or not
#
package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);
use Perl6::Junction qw(all);

use File::Basename ;

sub runGConf
{
    my ($self) = @_;

    $self->_migrateKeys();
    $self->_migrateNotification();
    $self->_removeKeys();

}

sub _removeKeys
{
  my ($self) = @_;

  my $mod = $self->{gconfmodule};
  my @deprecatedKeys = qw( 
                           AntispamConfiguration/enabled
                         );

  my @deprecatedDirs = qw(
                           General
                           AntivirusConfiguration
                           BadHeadersPolicy
                           BannedFilesPolicy
                           file_filter
                           spamassassin
                           clamav
                       );

  foreach my $key (@deprecatedKeys) {
      $mod->unset($key);
  }

  foreach my $dir (@deprecatedDirs) {
      $mod->dir_exists($dir) or
          next;
      $mod->delete_dir($dir);
  }
  

}

sub _migrateNotification
{
    my ($self) = @_;
    my $mod = $self->{gconfmodule};


    my $selected = $mod->get_string( 'General/notification_selected');

    my %migration = (
                     'General/notification_selected' => {
                                   newKey => 'AmavisConfiguration/notification_selected',
                                   getter => 'get_string',
                                   setter => 'set_string',
                                  },
                    );

    
    if ((defined $selected) and ($selected eq 'address')) {
        $migration{'General/address'} =  {
                                   newKey => 'AmavisConfiguration/address',
                                   getter => 'get_string',
                                   setter => 'set_string',
                                  };
    }

    $self->_migrateSimpleKeys($mod, \%migration);
}



sub _migrateKeys
{
  my ($self) = @_;

  my $mod = $self->{gconfmodule};

  my %deprecatedKeys = (
                        # to amavisConfigurationModel
                        'General/port' => {
                                   newKey => 'AmavisConfiguration/port',
                                   getter => 'get_int',
                                   setter => 'set_int',
                                  },
                        'BadHeadersPolicy/policy' => {
                                   newKey => 'AmavisPolicy/bhead',
                                   getter => 'get_string',
                                   setter => 'set_string',
                                  },
                        'BannedFilesPolicy/policy' => {
                                   newKey => 'AmavisPolicy/banned',
                                   getter => 'get_string',
                                   setter => 'set_string',
                                  },
                        'AntivirusConfiguration/policy' => {
                                   newKey => 'AmavisPolicy/virus',
                                   getter => 'get_string',
                                   setter => 'set_string',
                                  },
                        'AntispamConfiguration/policy' => {
                                   newKey => 'AmavisPolicy/spam',
                                   getter => 'get_string',
                                   setter => 'set_string',
                                  },
                       );


  $self->_migrateSimpleKeys($mod, \%deprecatedKeys);
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
              $dir . '/' . $_
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

my $mailfilterMod = EBox::Global->modInstance('mailfilter');
my $migration =  __PACKAGE__->new( 
        'gconfmodule' => $mailfilterMod,
        'version' => 5,
        );
$migration->execute();
1;


