# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Ldap;

use strict;
use warnings;

use Net::LDAP;
use Net::LDAP::Constant;
use Net::LDAP::Message;
use Net::LDAP::Search;
use Net::LDAP::LDIF;
use Net::LDAP qw(LDAP_SUCCESS);
use Net::LDAP::Util qw(ldap_error_name);

use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;
use EBox::UsersAndGroups::ImportFromLdif::Engine;
use EBox::Gettext;
use Data::Dumper;
use Encode qw( :all );

use Error qw(:try);
use File::Slurp qw(read_file);

use constant DN            => "dc=ebox";
use constant LDAPI         => "ldapi://%2fvar%2frun%2fslapd%2fldapi";
use constant LDAP          => "ldap://127.0.0.1";
use constant SLAPDCONFFILE => "/etc/ldap/slapd.conf";
use constant ROOTDN        => 'cn=admin,' . DN;
use constant INIT_SCRIPT   => '/etc/init.d/slapd';
use constant DATA_DIR      => '/var/lib/ldap';
use constant LDAP_USER     => 'openldap';
use constant LDAP_GROUP    => 'openldap';

# Singleton variable
my $_instance = undef;

sub _new_instance {
        my $class = shift;

        my $self = {};
        $self->{ldap} = undef;
        bless($self, $class);
        return $self;
}

# Method: instance
#
#   Return a singleton instance of class <EBox::Ldap>
#
# Returns:
#
#   object of class <EBox::Ldap>
sub instance
{
    my ($self) = @_;

    unless(defined($_instance)) {
        $_instance = EBox::Ldap->_new_instance();
    }

    return $_instance;
}

# Method: ldapCon 
#
#       Returns the Net::LDAP connection
#       
# Returns:    
#               
#       An object of class Net::LDAP whose connection has already bound       
#
# Exceptions: 
#               
#       Internal - If connection can't be created
sub ldapCon {
        my $self = shift;
        # Workaround to detect if connection is broken and force reconnection

        my $reconnect;
        if ($self->{ldap}) {
                my $mesg = $self->{ldap}->search(
                                base   => 'dc=ebox',
                                scope => 'base',                 
                                filter => "(cn=*)",
                                );
                


                if (ldap_error_name($mesg) ne 'LDAP_SUCCESS' ) { 
                  $self->{ldap}->unbind;
                  $reconnect = 1;
                }
        }


        if ((not defined $self->{ldap}) or $reconnect) {
                # We try to connect 5 times in 5 seconds, as we might need to 
                # give slapd some time to accept connections after a
                # slapd restart
                my $connected = undef;
                for (0..4) {
                        $self->{ldap} = Net::LDAP->new (LDAPI);
                        if ($self->{ldap}) {
                                $connected = 1;
                                last;
                        } else {
                                sleep (1);
                        }       
                }
                unless ($connected) {
                        throw EBox::Exceptions::Internal(
                                        "Can't create ldapi connection");
                }
                $self->{ldap}->bind(ROOTDN, password => getPassword());
        }

        return $self->{ldap};
}

# Method: getPassword 
#
#       Returns the password used to connect to the LDAP directory
#       
# Returns:    
#               
#       string - password
#
# Exceptions: 
#               
#       Internal - If password can't be read
sub getPassword {

        my $path = EBox::Config->conf . "/ebox-ldap.passwd";
        open(PASSWD, $path) or
                throw EBox::Exceptions::Internal("Could not open $path to " .
                                                 "get ldap password");

        my $pwd = <PASSWD>;
        close(PASSWD);

        $pwd =~ s/[\n\r]//g;

        return $pwd;
}


# Method: dn
#
#       Returns the dn
#       
# Returns:    
#               
#       string - dn
#
sub dn {
        return DN;
}

# Method: rootDn
#
#       Returns the dn of the priviliged user
#       
# Returns:    
#               
#       string - rootdn
#
sub rootDn {
        return ROOTDN
}

# Method: rootPw
#
#       Returns the password of the priviliged user
#       
# Returns:    
#               
#       string - password
#
sub rootPw {
        return getPassword();
}

# Method: slapdConfFile
#
#       Returns the location of the slapd's configuration file
#       
# Returns:    
#               
#       string - location
#
sub slapdConfFile {
        return SLAPDCONFFILE;
}

# Method: ldapConf
#
#       Returns the current configuration for LDAP: 'dn', 'ldapi', 'rootdn'
#       
# Returns:    
#               
#     hash ref  - holding the keys 'dn', 'ldapi', 'ldap', and 'rootdn' 
#
sub ldapConf {
        my ($class) = @_;
        
        my $conf = {
                     'dn'     => DN,
                     'ldapi'  => LDAPI,
                     'ldap'   => LDAP,
                     'rootdn' => ROOTDN,
                   };
        return $conf;
}

# Method: search
#
#       Performs a search in the LDAP directory using Net::LDAP. 
#       
# Parameters:
#
#       args - arguments to pass to Net::LDAP->search()
#               
# Exceptions:
#
#       Internal - If there is an error during the search
sub search($$) # (args)
{
        my $self = shift;
        my $args = shift;

        $self->ldapCon; 
        my $result = $self->{ldap}->search(%{$args});
        _errorOnLdap($result, $args);
        return $result;
        
}

# Method: modify
#
#       Performs  a  modification in the LDAP directory using Net::LDAP. 
#       
# Parameters:
#
#       dn - dn where to perform the modification 
#       args - parameters to pass to Net::LDAP->modify()
#               
# Exceptions:
#
#       Internal - If there is an error during the search
sub modify($$) {
        my $self = shift;
        my $dn   = shift;
        my $args = shift;

        $self->ldapCon; 
        my $result = $self->{ldap}->modify($dn, %{$args});
        _errorOnLdap($result, $args);
        return $result;

}

# Method: delete
#
#       Performs  a deletion  in the LDAP directory using Net::LDAP. 
#       
# Parameters:
#
#       dn - dn to delete 
#               
# Exceptions:
#
#       Internal - If there is an error during the search
sub delete($$) {
        my $self = shift;
        my $dn   = shift;
        
        $self->ldapCon; 
        my $result =  $self->{ldap}->delete($dn);
        _errorOnLdap($result, $dn);
        return $result;

}

# Method: add
#
#       Adds an object or attributes  in the LDAP directory using Net::LDAP. 
#       
# Parameters:
#
#       dn - dn to add
#       args - parameters to pass to Net::LDAP->add()
#               
# Exceptions:
#
#       Internal - If there is an error during the search

sub add($$) {
        my $self = shift;
        my $dn   = shift;
        my $args = shift;
        
        $self->ldapCon; 
        my $result =  $self->{ldap}->add($dn, %{$args});
        _errorOnLdap($result, $args);
        return $result;
}

# Method: delObjectclass
#
#       Remove an objectclass from an object an all its associated attributes
#       
# Parameters:
#
#       dn - object's dn
#       objectclass - objectclass
#               
# Exceptions:
#
#       Internal - If there is an error during the search
sub delObjectclass # (dn, objectclass);
{
        my $self = shift;
        my $dn   = shift;
        my $objectclass = shift;

        my $schema = $self->ldapCon->schema();
        my $msg = $self->search(
                                { base => $dn, scope => 'base',
                                  filter => "(objectclass=$objectclass)"
                                });
        _errorOnLdap($msg);
        return unless ($msg->entries > 0);

        my %attrexist = map {$_ => 1} $msg->pop_entry->attributes; 


        $msg = $self->search(
                                { base => $dn, scope => 'base',
                                  attrs => ['objectClass'], 
                                  filter => '(objectclass=*)'
                                });
        _errorOnLdap($msg);
        my %attrs;
        for my $oc (grep(!/^$objectclass$/, $msg->entry->get_value('objectclass'))){
                # get objectclass attributes
                my @ocattrs =  map { 
                  $_->{name}
                }  ($schema->must($oc), $schema->may($oc));

                # mark objectclass attributes as seen
                foreach (@ocattrs) {
                  $attrs{$_ } = 1;
                }
              }

        # get the attributes of the object class which will be deleted
        my @objectAttrs = map {
          $_->{name}
        }  ($schema->must($objectclass), $schema->may($objectclass));


        my %attr2del;
        for my $attr (@objectAttrs) {
                # Skip if the attribute belongs to another objectclass
                next if (exists $attrs{$attr});
                # Skip if the attribute is not stored in the object
                next unless (exists $attrexist{$attr});
                $attr2del{$attr} = [];
        }

        my $result;
        if (%attr2del) {
                $result = $self->modify($dn, { changes => 
                        [delete =>[ objectclass => $objectclass, %attr2del ] ] });
                _errorOnLdap($msg);
        } else {
                $result = $self->modify($dn, { changes => 
                        [delete =>[ objectclass => $objectclass ] ] });
                _errorOnLdap($msg);
        }
        return $result;
}

# Method: modifyAttribute 
#
#       Modify an attribute from a given dn
#       
# Parameters:
#
#       dn - object's dn
#       attribute - attribute to change
#       value - new value
#               
# Exceptions:
#
#       Internal - If there is an error during the modification
#       
sub modifyAttribute # (dn, attribute, value);
{
        my ($self, $dn, $attribute, $value) = @_;

        my %attrs = ( changes => [ replace => [ $attribute => $value ] ]);
        $self->modify($dn, \%attrs ); 
}


#
#   Method: isObjectClass
#
#      check if a object is member of a given objectclass
#
# Parameters:
#          dn          - the object's dn
#          objectclass - the name of the objectclass
# 
#  Returns:
#    boolean - wether the object is member of the objectclass or not
sub isObjectClass
{
  my ($self, $dn, $objectClass) = @_;


  my %attrs = (
               base   => $dn,
               filter => "(objectclass=$objectClass)",
               attrs  => [ 'objectClass'],
               scope  => 'base'
              );
  
  my $result = $self->search(\%attrs);
  
  if ($result->count ==  1) {
      return 1;
  }

  return undef;
}

sub _errorOnLdap 
{
    my ($result, $args) = @_;

    my  @frames = caller (2);
    if ($result->is_error){
        if ($args) {
            use Data::Dumper;
            EBox::error( Dumper($args) );
        }
        throw EBox::Exceptions::Internal("Unknown error at " .
                                         $frames[3] . " " .
                                         $result->error);
    }
}

# Workaround to mark strings returned from ldap as utf8 strings
sub _utf8Attrs # (result)
{
    my ($result) = @_;

    my @entries = $result->entries;
    foreach my $attr (@{$entries[0]->{'asn'}->{'attributes'}}) {
        my @vals = @{$attr->{vals}};
                next unless (@vals);
        my @utfvals;
        foreach my $val (@vals) {
            _utf8_on($val);
            push @utfvals, $val;
        }
        $attr->{vals} = \@utfvals;
    }

    return $result;
}



sub  dataDir
{
  my ($self) = @_;
  return DATA_DIR;
#   my @conf = read_file(slapdConfFile());
  
#   @conf = map { my ($withoutComments) = split '#', $_; $withoutComments    } @conf;
#   my ($directoryLine) = grep { m/^\s*directory\s+/ } @conf;
#   chomp $directoryLine;
#   my ($keyword, $value) = split '\s+', $directoryLine;
  
#   $value or throw EBox::Exceptions::External((__('Can not get data directory path from ldap')));

#   return $value;

} 

sub stop
{
  my ($self) = @_;

  EBox::Sudo::root(INIT_SCRIPT . ' stop');

  sleep 1;  
  return  $self->refreshLdap();
} 

sub  start
{
  my ($self) = @_;

  EBox::Sudo::root(INIT_SCRIPT . ' start');

  sleep 1;
  return  $self->refreshLdap();
} 


sub refreshLdap
{
  my ($self) = @_;

  $self->{ldap} = undef;
  return $self;
}



sub ldifFile
{
  my ($self, $dir) = @_;
  return "$dir/ldap.ldif";
}

# Method: dumpLdapData
#
#  dump the LDAP contents to a LDIF file in the given directory. The exact file
#  path can be retrevied using the method ldifFile
#  
#    Parameters:
#       dir - directory in which put the LDIF file
sub dumpLdapData
{
  my ($self, $dir) = @_;
  
  my $ldapDir       = EBox::Ldap::dataDir();
  my $slapdConfFile = EBox::Ldap::slapdConfFile();
  my $user  = EBox::Config::user();
  my $group = EBox::Config::group();
  my $ldifFile = $self->ldifFile($dir);

  my $slapcatCommand = $self->_slapcatCmd($ldifFile, $slapdConfFile);
  my $chownCommand = "/bin/chown $user.$group $ldifFile";

  $self->_pauseAndExecute(cmds => [$slapcatCommand, $chownCommand]);
} 

# Method: loadLdapData
#
#  load all the raw LDAP data found in the LDIF file
#  
#    Parameters:
#       dir - directory in which is the LDIF file
# XXX: todo add on error sub
sub loadLdapData
{
  my ($self, $dir) = @_;
  
  my $ldapDir   = EBox::Ldap::dataDir();
  my $slapdConfFile = EBox::Ldap::slapdConfFile();
  my $ldifFile = $self->ldifFile($dir);

  my $backupCommand = $self->_backupSystemDirectory();
  my $rmCommand = $self->_rmLdapDirCmd($ldapDir);
  my $slapaddCommand = $self->_slapaddCmd($ldifFile, $slapdConfFile);
  my $chownDataCommand = $self->_chownDatadir;
  
  $self->_pauseAndExecute(
                cmds => [$backupCommand, $rmCommand, 
                         $slapaddCommand, $chownDataCommand 
                        ]);
}

# Method: importLdapData
#
#    import in eBox the data found in LDIF file. Import classes for the various
#    modules are used to load the data
#  
#    Parameters:
#       dir - directory in which is the LDIF file
sub importLdapData
{
  my ($self, $dir) = @_;
  
  my $ldifFile = $self->ldifFile($dir);

  EBox::UsersAndGroups::ImportFromLdif::Engine::importLdif($ldifFile);
}


sub _chownDatadir
{
        return 'chown -R '  . LDAP_USER . ':' . LDAP_GROUP . ' ' . dataDir();
}

sub _slapcatCmd
{
  my ($self, $ldifFile, $slapdConfFile) = @_;
  return  "/usr/sbin/slapcat  -f $slapdConfFile > $ldifFile";
}

sub _slapaddCmd
{
  my ($self, $ldifFile, $slapdConfFile) = @_;
  return  "/usr/sbin/slapadd  -c -f $slapdConfFile < $ldifFile" ;
}

sub _rmLdapDirCmd
{
  my ($self, $ldapDir)   = @_;
  $ldapDir .= '/*' if  defined $ldapDir ;

  return "sh -c '/bin/rm -rf $ldapDir'";
}

sub _backupSystemDirectory
{
  my ($self) = @_;
  
  return EBox::Config::share() . '/ebox-usersandgroups/slapd.backup';
}

sub _pauseAndExecute
{
  my ($self, %params) = @_;
  my @cmds = @{ $params{cmds}  };
  my $onError = $params{onError};

  $self->stop();
  try {
    foreach my $cmd (@cmds) {
      EBox::Sudo::root($cmd);
    }
   }
  otherwise {
    my $ex = shift;

    if ($onError) {
      $onError->($self);
    }

    throw $ex;
  }
  finally {
    $self->start();
  };
}



1;
