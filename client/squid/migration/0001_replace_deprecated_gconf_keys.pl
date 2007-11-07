#!/usr/bin/perl

#  Migration between gconf data version 0 and 1
#
#   gconf changes: now service is explitted in intrnalService and userService
#   files changes: now log files names have the name of the daemon instead of
#   the iface daemons change: now start and stop of daemons have a new method
#   depending in pid files
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;

use Perl6::Junction qw(any all);


sub runGConf
{
  my ($self) = @_;

  $self->_migrateKeys();
  $self->_migrateDomains();
  $self->_migrateExtensions();
  $self->_migrateMIMETypes();
  $self->_migrateObjects();
}



sub _migrateKeys
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};

  my %deprecatedKeys = (
			# to squid service models
			active => {
				   newKey => 'SquidService/enabled',
				   getter => 'get_bool',
				   setter => 'set_bool',
				  },

			# to general settings model
			policy => {
					 newKey => 'GeneralSettings/globalPolicy',
					 setter => 'set_string',
					 getter => 'get_string',
					},
			transproxy => {
				       newKey => 'GeneralSettings/transparentProxy',
				       setter => 'set_bool',
				       getter => 'get_bool',
				      },
			port => {
					 newKey => 'GeneralSettings/port',
					 setter => 'set_int',
					 getter => 'get_int',
					},
			
			# to another model
			threshold => {
				      newKey => 
				      'ContentFilterThreshold/contentFilterThreshold',
				      setter => 'set_int',
				      getter => 'get_int',
				     },
		       );


  $self->_migrateSimpleKeys($squid, \%deprecatedKeys);
}





sub _migrateSimpleKeys
{
  my ($self, $squid, $deprecatedKeys_r) = @_;

  my $entries = $squid->all_entries_base('') ;  
  my $allExistentKeys = all  @{ $entries };
  while (my ($oldKey, $migrationSpec) = each %{ $deprecatedKeys_r }) {
    if ( $oldKey ne $allExistentKeys ) {
      next;
    }

    my $newKey = $migrationSpec->{newKey};
    my $getter = $migrationSpec->{getter};
    my $setter = $migrationSpec->{setter};


    my $oldValue  = $squid->$getter($oldKey);
    $squid->$setter($newKey, $oldValue);
    
    $squid->unset($oldKey);
  }
}

sub _migrateDomains
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};
  my $domainFilter = $squid->model('DomainFilter');

  my $allowedSites_r = $squid->get_list('allowed_sites');
  foreach my $domain (@{ $allowedSites_r }) {
    $domainFilter->addRow(
			  domain => $domain,
			  policy => 'allow',
			 );
  }
  $squid->unset('allowed_sites');

  
  my $bannedSites_r = $squid->get_list('banned_sites');
  foreach my $domain (@{ $bannedSites_r }) {
    $domainFilter->addRow(
			  domain => $domain,
			  policy => 'deny',
			 );
  }
  $squid->unset('banned_sites');					 
					


  $self->_listsToTable('allowed_sites', 'banned_sites', $domainFilter, 'domain');
}

sub _migrateExtensions
{
  my ($self) = @_;

  $self->_migrateAllowAndBanList(
				 populateMethod => '_populateExtensions',
				 
				 newModelName => 'ExtensionFilter',
				 newModelDir  =>  'EBox::Squid::Model::ExtensionsFilter',
				 newModelElementType => 'extension',

				 allowListKey   => 'allowed_extensions',
				 banListKey     => 'banned_extensions',
				);
}

sub _migrateAllowAndBanList
{
  my ($self, %args) = @_;

  my $populateMethod = $args{populateMethod};

  my $newModelName = $args{newModelName};
  my $newModelDir  = $args{newModelDir};
  my $newModelElementType = $args{newModelElementType};
  
  my $allowListKey   = $args{allowListKey};
  my $banListKey     = $args{banListKey};

  my $status = $self->_populatedStatus($newModelDir, $allowListKey, $banListKey);
  if ( $status->{populated} eq 'no' ) {
    return $self->$populateMethod();
  }
 
  my $squid = $self->{gconfmodule};
  my $newModel = $squid->model($newModelName);  

  if ($status->{populated} eq 'yes') {
    $self->_listsToTable($allowListKey, $banListKey, $newModel, $newModelElementType);
    return;
  }

  if ($status->{populated} eq 'partial') {
    my $missing = $status->{missing};
    my $force = 0;
    if ($missing == 0) {
      $force = 1; # XXX this is bz the dafult changed from 0 to 1!!
    }


    # migrate the setted data
    if ($missing == 0) {
      $self->_listsToTable($allowListKey, undef, $newModel, $newModelElementType);
    }
    elsif ($missing == 1) {
      $self->_listsToTable(undef, $banListKey, $newModel, $newModelElementType);
    }
    else {
      die 'must not be reached';
    }

    # .. and populate the other half
    $self->$populateMethod($missing, $force);

    return;
  }

  die 'must not be reached';

}





sub _populateExtensions
{
  my ($self, $onlyAllowType, $force) = @_;

  my $defaultAllow = 1;

  if (defined $onlyAllowType)  {
    if ($onlyAllowType != $defaultAllow) {
      if ( $force) {
	$defaultAllow = $onlyAllowType;
      }
    }
  }

  my @extensions = qw(
                     ade adp asx bas bat cab chm cmd com cpl crt dll exe hlp 
                     ini hta inf ins isp lnk mda mdb mde mdt mdw mdz msc msi 
                     msp mst pcd pif prf reg scf scr sct sh shs shb sys url vb 
                     be vbs vxd wsc wsf wsh otf ops doc xls gz tar zip tgz bz2 
                     cdr dmg smi sit sea bin hqx rar mp3 mpeg mpg avi asf iso 
                     ogg wmf  cue sxw stw stc sxi sti sxd sxg odt ott ods 
                     ots odp otp odg otg odm odf odc odb odi pdf
                   );

  my $squid = $self->{gconfmodule};

  my $extensionFilter = $squid->model('ExtensionFilter');
  foreach my $extension (@extensions) {
    $extensionFilter->addRow(
			     extension => $extension,
			     allowed     => $defaultAllow,
			    );
  }

}



# returns:
#     populated -> ('yes', 'no', 'partial')
#     missing   ->  boo # (only when populated == 'partial'
#    partialPopulated -bool
#     allowPop
sub _populatedStatus
{
  my ($self, $dir, $allowList, $banList) = @_;

  my $squid = $self->{gconfmodule};  

  if ($squid->dir_exists($dir)) {
    return {
	    populated => 'yes',
	   };
  }
  



  my @entries = @{ $squid->all_entries_base('') };
  my $allowPopulated =  $allowList eq any @entries;
  my $banPopulated   =  $banList eq any @entries;

  if ($allowPopulated and $banPopulated) {
    return {
	    populated => 'yes',
	   };
  }
  elsif ($allowPopulated and not $banPopulated) {
    return {
	    populated => 'partial',
	    missing  =>  0,
	   }
  }
  elsif (not $allowPopulated and $banPopulated) {
    return {
	    populated => 'partial',
	    missing  => 1,  
	   }
  }

  return  { populated => 'no'   };
}

sub _migrateMIMETypes
{
  my ($self) = @_;

  $self->_migrateAllowAndBanList(
				 populateMethod => '_populateMIMETypes',
				 
				 newModelName => 'MIMEFilter',
				 newModelDir  =>  'EBox::Squid::Model::MIMEFilter',
				 newModelElementType => 'MIMEType',

				 allowListKey   => 'allowed_mimetype',
				 banListKey     => 'banned_mimetype',
				);
}


sub _populateMIMETypes
{
  my ($self, $onlyAllowType, $force) = @_;

  my $squid = $self->{gconfmodule};

  my $defaultAllow = 1;

  if ($onlyAllowType != $defaultAllow) {
    if ( $force) {
      $defaultAllow = $onlyAllowType;
    }
  }


  my @mimeTypes = qw(
                    audio/mpeg audio/x-mpeg audio/x-pn-realaudio audio/x-wav 
                    video/mpeg video/x-mpeg2 video/acorn-replay video/quicktime 
                    video/x-msvideo video/msvideo application/gzip 
                    application/x-gzip application/zip application/compress 
                   application/x-compress application/java-vm
                  );


  my $mimeFilter = $squid->model('MIMEFilter');
  foreach my $mimeType (@mimeTypes) {
    $mimeFilter->addRow(
			MIMEType => $mimeType,
			allowed    => $defaultAllow,
		       );
  }
}





sub _listsToTable
{
  my ($self, $allowedKey, $bannedKey, $model, $elementType) = @_;

  my $squid = $self->{gconfmodule};
  my $allowedList = defined $allowedKey ? $squid->get_list($allowedKey): [];
  my $bannedList  = defined $bannedKey  ? $squid->get_list($bannedKey) : [];


  my %elements;
  foreach (@{  $allowedList }) {
    $elements{$_} = 1;
  }
  foreach (@{  $bannedList }) {
    $elements{$_} = 0;
  }

  while (my ($element, $allowed) = each %elements) {
    $model->addRow(
			  $elementType  => $element,
			  allowed => $allowed,
			 )
  }

  $squid->unset($allowedKey);
  $squid->unset($bannedKey);
}

sub _migrateObjects
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};
  my $objectPolicy = $squid->model('ObjectPolicy');

  my @allowed  = @{ $squid->get_list('unfiltered') };
  foreach my $object (@allowed) {
    $objectPolicy->addRow(
			  object => $object,
			  policy => 'allow',
			 );
  }

  my @banned   = @{ $squid->get_list('bans') };
  foreach my $object (@banned) {
    $objectPolicy->addRow(
			  object => $object,
			  policy => 'deny',
			 );
  }

  $squid->unset('unfiltered');
  $squid->unset('bans');
}



EBox::init();
my $squid = EBox::Global->modInstance('squid');
my $migration = new EBox::Migration( 
				     'gconfmodule' => $squid,
				     'version' => 1,
				    );
$migration->execute();				     


1;
