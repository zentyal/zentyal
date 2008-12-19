package EBox::Mail::Test;
use base 'EBox::Test::Class';
# Description:
use strict;
use warnings;


use File::Slurp::Tree;
use Test::More;
use Test::Exception;
use Test::Differences;
use Test::MockObject;
use EBox::Global;
use EBox::Test qw(checkModuleInstantiation);
use EBox::TestStubs qw(fakeEBoxModule);

use Perl6::Junction qw(all any);

use EBox::NetWrappers::TestStub;


use lib '../..';

sub testDir
{
    return  '/tmp/ebox.mail.test';
}


sub cleanTestDir : Test(startup)
{
  my ($self) = @_;

  my $dir = $self->testDir();
  system  " rm -rf  $dir";
  mkdir $dir;
}


sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;
   

    my @config = (
                  '/ebox/modules/mail/active'  => 1,
                  '/ebox/modules/mail/filter'  => 1,
                  '/ebox/modules/mail/external_filter_name'  => 'custom',
                  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('mail' => 'EBox::Mail');

    EBox::TestStubs::fakeEBoxModule(name => 'firewall',
                                    subs => [
                                             availablePort => sub { 
                                               return 1
                                             },
                                             ]
                                   );
 }


# we fake this to returns that always are one interface. (this is for the
# setIpFilter method)
sub fakeGetIfacesForAddress 
{
  Test::MockObject->fake_module('EBox::Mail',
                                '_getIfacesForAddress' => sub { return ['eth0']  },
                               );
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}

sub _moduleTest : Test(4)
{
    checkModuleInstantiation('mail', 'EBox::Mail');
    use_ok 'EBox::Mail::FilterProvider';


  my $mail = EBox::Global->modInstance('mail');
    EBox::Test::checkModels($mail,
                            qw(SMTPAuth SMTPOptions RetrievalServices 
                               ObjectPolicy VDomains ExternalFilter
                               GreylistConfiguration MailDispatcherConfiguration
                               )

                           );

    EBox::Test::checkComposites($mail,
                            qw( ServiceConfiguration General )

                           );
}


sub extendedRestoreTest : Test(7)
{
  my ($self) = @_;

  my $varDir = $self->testDir() . '/var';
  mkdir $varDir;

  my $md  = 'mail.backup';
  my $vmd =  'vmail.backup';
  my @backupDirs =  map {  $varDir . "/$_"   }($md, $vmd);
  _fakeStorageMailDirs(@backupDirs);

  my $mail = EBox::Global->modInstance('mail');

  # we will try first with no files in mailboxes

  mkdir $_ foreach (@backupDirs);
  lives_ok { $mail->extendedBackup( dir => $self->testDir )  } 'Running extendedBackup with empty mailboxes';


  # creating new files in the dirss to be restored
  system "touch $_/shouldNotBeHereAfterRestore" foreach @backupDirs;

  lives_ok { $mail->extendedRestore( dir => $self->testDir )  } 'Running extendedRestore with an archive which has empty mailboxes';
  foreach my $d (@backupDirs) {
    if ( -d $d ) {
      my @nFiles =  `ls -1 $d`;
      is @nFiles, 0, "Checking wether contents of restored dir $d were replaced with the contents of the archive (no mailboxes)";
    }
    else {
      ok 0, "$d must exist";  
    }
  }


  # setup backup dirs

  my $beforeBackup = {
                       $md => {
                              root => {  "mbox" => 'fake mbox', },
                             },

                      $vmd => {
                               'monos.org' => {
                                               macaco => {
                                                          tmp => {},
                                                          new => { 
                                                                  '1177498277.V801Id1438.localhost.localdomain,S=690' => 'fake mail',
                                                                 },
                                                          cur => {},
                                                          maildirsize => 'fake file',
                                                         },
                                              },

                              },

                     };

  my $afterBackup  = {
                      $md => {
                             },

                      $vmd => {
                               'monos.org' => {
                                               macaco => {
                                                          tmp => {},
                                                          new => { 
                                                                 },
                                                          cur => {
                                                                  '1177498277.V801Id1438.localhost.localdomain,S=690' => 'fake mail',
                                                                 },
                                                          maildirsize => 'fake file',
                                                         },
                                              },

                              },

                    };

  system "rm -rf @backupDirs";
  spew_tree($varDir => $beforeBackup );
  lives_ok { $mail->extendedBackup( dir => $self->testDir )  } 'Running extendedBackup';


  # setup restore dirs
  spew_tree($varDir => $afterBackup );
  lives_ok { $mail->extendedRestore( dir => $self->testDir )  } 'Running extendedRestore';
  
  my $afterRestore = slurp_tree($varDir);
  is_deeply $afterRestore, $beforeBackup, 'Checking restored mail archives';
}






sub _fakeStorageMailDirs
{
  my (@dirs) = @_;

  Test::MockObject->fake_module('EBox::Mail',
                                _storageMailDirs => sub { return @dirs }
                               );
}



# fake methods needed for the test..
{
  no warnings;
  sub EBox::Mail::_getIfacesForAddress
    {
      return ['eth0']  ;
    }
}

1;
