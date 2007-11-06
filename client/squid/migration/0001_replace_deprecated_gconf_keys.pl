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

use Perl6::Junction qw(any);


sub runGConf
{
  my ($self) = @_;

  $self->_migrateService();
  $self->_migrateGeneralSettings();
  $self->_migrateDomains();
  $self->_migrateExtensions();
  $self->_migrateMIMETypes();
  $self->_migrateObjects();

  my $squid = $self->{gconfmodule};
  $squid->setTablesAsPopulated();
}


sub _migrateService
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};

  my $service = $squid->get_bool('active');

  my $squidService = $squid->model('SquidService');
  $squidService->setRow(
			0, # force 
			enabled => $service
		       );

  $squid->unset('active');
}


sub _migrateGeneralSettings
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};
  
  my $policy  = $squid->get_string('policy');
  $policy or $policy = 'deny';
  my $transproxy = $squid->get_bool('transproxy');
  $transproxy or $transproxy = 0;
  my $port       = $squid->get_int('port');
  $port or $port = 3128;
  my $threshold  = $squid->get_int('threshold');
  $threshold or $threshold = 0;

  if (($policy eq 'filter') and ($threshold == 0)) {
    # this configuration combination is not longer value so we set the threshold
    # to 'very permissive' to avoid errors
    $threshold = 200;
  }


  my $generalSettings = $squid->model('GeneralSettings');
  $generalSettings->setRow(
			   0, # force
			   globalPolicy     => $policy,
			   port             => $port,
			   contentFilterThreshold => $threshold,
			   transparentProxy => $transproxy,
			  );

  # Disable unsetting old keys while migration script is still buggy
  # my @deprecatedKeys = qw(policy transproxy port threshold);
  # foreach (@deprecatedKeys) {
    # $squid->unset($_);
  #}
}


sub _migrateDomains
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};
  my $domainFilter = $squid->model('DomainFilter');
  $self->_listsToTable('allowed_sites', 'banned_sites', $domainFilter, 'domain');
}

sub _migrateExtensions
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};

  if ($self->_notPopulated('EBox::Squid::Model::ExtensionsFilter', 'allowed_extensions', 'banned_extensions')) {
    return $self->_populateExtensions();
  }

  my $extensionFilter = $squid->model('ExtensionFilter');
  $self->_listsToTable('allowed_extensions', 'banned_extensions', $extensionFilter, 'extension');
}





sub _populateExtensions
{
  my ($self) = @_;

  my $defaultAllow = 1;
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




sub _notPopulated
{
  my ($self, $dir, $allowList, $banList) = @_;

  my $squid = $self->{gconfmodule};  

  if ($squid->dir_exists($dir)) {
    return 0;
  }
  
  my @entries = @{ $squid->all_entries_base('') };
  if ($allowList eq any @entries) {
    return 0;
  }
  elsif ($banList eq any @entries) {
    return 0;
  }

  return 1;
}

sub _migrateMIMETypes
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};

  if ($self->_notPopulated('EBox::Squid::Model::MIMEFilter', 'allowed_mimetype', 'banned_mimetype')) {
    return $self->_populateMIMETypes();
  }

  my $mimetypeFilter = $squid->model('MIMEFilter');
  $self->_listsToTable('allowed_mimetype', 'banned_mimetype', $mimetypeFilter, 'MIMEType');
}


sub _populateMIMETypes
{
  my ($self) = @_;

  my $squid = $self->{gconfmodule};

  my $defaultAllow = 1;
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
  my $allowedList = $squid->get_list($allowedKey);
  my $bannedList = $squid->get_list($bannedKey);


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
