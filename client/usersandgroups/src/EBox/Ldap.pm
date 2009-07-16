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

use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;
use EBox::UsersAndGroups::ImportFromLdif::Engine;
use EBox::Gettext;

use Net::LDAP;
use Net::LDAP::Constant;
use Net::LDAP::Message;
use Net::LDAP::Search;
use Net::LDAP::LDIF;
use Net::LDAP qw(LDAP_SUCCESS);
use Net::LDAP::Util qw(ldap_error_name);

use Data::Dumper;
use Encode qw( :all );
use Error qw(:try);
use File::Slurp qw(read_file write_file);
use Apache2::RequestUtil;

use constant LDAPI         => "ldapi://%2fvar%2frun%2fslapd%2fldapi";
use constant LDAP          => "ldap://127.0.0.1";
use constant SLAPDCONFFILE => "/etc/ldap/slapd.conf";
use constant INIT_SCRIPT   => '/etc/init.d/slapd';
use constant DATA_DIR      => '/var/lib/ldap';
use constant LDAP_USER     => 'openldap';
use constant LDAP_GROUP    => 'openldap';

# Singleton variable
my $_instance = undef;

sub _new_instance
{
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
    my ($self, %opts) = @_;

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
sub ldapCon
{
    my ($self) = @_;

    # Workaround to detect if connection is broken and force reconnection
    my $reconnect;
    if ($self->{ldap}) {
        my $mesg = $self->{ldap}->search(
                base   => '',
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
        my $global = EBox::Global->getInstance();
        my ($dn, $pass);
        my $auth_type = undef;
        try {
            my $r = Apache2::RequestUtil->request();
            $auth_type = $r->auth_type;
        } catch Error with {};

        if ((not defined($auth_type)) or ($auth_type eq 'EBox::Auth')) {
            $dn = $self->rootDn();
            $pass = $self->getPassword();
        } elsif ($auth_type eq 'EBox::UserCorner::Auth') {
            eval "use EBox::UserCorner::Auth";
            if ($@) {
                throw EBox::Exceptions::Internal("Error loading class EBox::UserCorner::Auth: $@")
            }
            my $credentials = EBox::UserCorner::Auth->credentials();
            my $users = EBox::Global->modInstance('users');
            $dn = $users->userDn($credentials->{'user'});
            $pass = $credentials->{'pass'};
            EBox::debug('dn: ' . $dn);
            EBox::debug('pass: ' . $pass);
        } else {
            throw EBox::Exceptions::Internal("Unknown auth_type: $auth_type");
        }
        $self->{ldap}->bind($dn, password => $pass);
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
sub getPassword
{
    my ($self) = @_;

    unless (defined($self->{password})) {
        my $path = EBox::Config->conf . "/ebox-ldap.passwd";
        open(PASSWD, $path) or
            throw EBox::Exceptions::Internal("Could not open $path to " .
                    "get ldap password");

        my $pwd = <PASSWD>;
        close(PASSWD);

        $pwd =~ s/[\n\r]//g;
        $self->{password} = $pwd;
    }
    return $self->{password};
}

sub getSlavePassword
{
    my ($self) = @_;

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
#       Returns the base dn
#
# Returns:
#
#       string - dn
#
sub dn {
    my ($self) = @_;
    if(!defined($self->{dn})) {
        $self->ldapCon();
        my %args = (
            'base' => '',
            'scope' => 'base',
            'filter' => '(objectclass=*)',
            'attrs' => ['namingContexts']
        );
        my $result = $self->{ldap}->search(%args);
        my $entry = ($result->entries)[0];
        my $attr = ($entry->attributes)[0];
        $self->{dn} = $entry->get_value($attr);
    }
    return $self->{dn};
}

# Method: rootDn
#
#       Returns the dn of the priviliged user
#
# Returns:
#
#       string - eboxdn
#
sub rootDn {
    my ($self, $dn) = @_;
    unless(defined($dn)) {
        $dn = $self->dn();
    }
    return 'cn=ebox,' . $dn;
}

# Method: rootPw
#
#       Returns the password of the priviliged user
#
# Returns:
#
#       string - password
#
sub rootPw
{
    my ($self) = @_;
    return $self->getPassword();
}

# Method: slapdConfFile
#
#       Returns the location of the slapd's configuration file
#
# Returns:
#
#       string - location
#
sub slapdConfFile
{
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
    my ($self) = @_;

    my $conf = {
        'dn'     => $self->dn(),
        'ldapi'  => LDAPI,
        'ldap'   => LDAP,
        'port' => 389,
        'replicaport' => 1389,
        'translucentport' => 1390,
        'rootdn' => $self->rootDn(),
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
sub search # (args)
{
    my ($self, $args) = @_;

    $self->ldapCon;
    #FIXME: this was added to deal with a problem where an object wouldn't be
    #returned if attributes were required but objectclass wasn't required too
    #it's apparently working now, so it's commented, remove it if it works
#    if (exists $args->{attrs}) {
#        my %attrs = map { $_ => 1 } @{$args->{attrs}};
#        unless (exists $attrs{objectClass}) {
#                push (@{$args->{attrs}}, 'objectClass');
#        }
#    }
    my $result = $self->{ldap}->search(%{$args});
    _errorOnLdap($result, $args);
    return $result;
}

# Method: modify
#
#       Performs a modification in the LDAP directory using Net::LDAP.
#
# Parameters:
#
#       dn - dn where to perform the modification
#       args - parameters to pass to Net::LDAP->modify()
#
# Exceptions:
#
#       Internal - If there is an error during the search
sub modify
{
    my ($self, $dn, $args) = @_;

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
sub delete
{
    my ($self, $dn) = @_;

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

sub add # (dn, args)
{
    my ($self, $dn, $args) = @_;

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
    my ($self, $dn, $objectclass) = @_;

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

# Method: setAttribute
#
#       Modify the value of an attribute from a given dn if it exists
#       Add the attribute with the given value if it doesn't exist
#
# Parameters:
#
#       dn - object's dn
#       attribute - attribute to add/change
#       value - new value
#
# Exceptions:
#
#       Internal - If there is an error during the modification
#
sub setAttribute # (dn, attribute, value);
{
    my ($self, $dn, $attribute, $value) = @_;

    my %args = (base => $dn, filter => "$attribute=*");
    my $result = $self->search(\%args);
    my $action = $result->count > 0 ? 'replace' : 'add';

    my %attrs = ( changes => [ $action => [ $attribute => $value ] ]);
    $self->modify($dn, \%attrs);
}

# Method: delAttribute
#
#       Delete an attribute from a given dn if it exists
#
# Parameters:
#
#       dn - object's dn
#       attribute - attribute to delete
#
# Exceptions:
#
#       Internal - If there is an error during the modification
#
sub delAttribute # (dn, attribute);
{
    my ($self, $dn, $attribute, $value) = @_;

    my %args = (base => $dn, filter => "$attribute=*");
    my $result = $self->search(\%args);
    if ($result->count > 0) {
        my %attrs = ( changes => [ delete => [ $attribute => [] ] ]);
        $self->modify($dn, \%attrs);
    }
}

# Method: getAttribute
#
#       Get the value for the given attribute.
#       If there are more than one, the first is returned.
#
# Parameters:
#
#       dn - object's dn
#       attribute - attribute to get its value
#
# Returns:
#       string - attribute value if present
#       undef  - if attribute not present
#
# Exceptions:
#
#       Internal - If there is an error during the modification
#
sub getAttribute # (dn, attribute);
{
    my ($self, $dn, $attribute) = @_;

    my %args = (base => $dn, filter => "$attribute=*");
    my $result = $self->search(\%args);

    return undef unless ($result->count > 0);

    return $result->entry(0)->get_value($attribute);
}


# Method: isObjectClass
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

# Method: objectClasses
#
#      return the object classes of an object
#
# Parameters:
#          dn          - the object's dn
#
#  Returns:
#    array - containing the object classes
sub objectClasses
{
    my ($self, $dn) = @_;

    my %attrs = (
            base   => $dn,
            filter => "(objectclass=*)",
            attrs  => [ 'objectClass'],
            scope  => 'base'
            );

    my $result = $self->search(\%attrs);

    return [ $result->pop_entry()->get_value('objectClass') ];
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

sub confDir
{
    my ($slapd) = @_;
    if ($slapd eq 'master') {
        return "/etc/ldap/slapd.d";
    } else {
        return "/etc/ldap/slapd-$slapd.d";
    }
}

sub dataDir
{
    my ($slapd) = @_;
    if ($slapd eq 'master') {
        return "/var/lib/ldap/";
    } else {
        return "/var/lib/ldap-$slapd/";
    }
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
    my ($self, $dir, $conf, $base) = @_;
    return "$dir/$conf-$base.ldif";
}

# Method: dumpLdap
#
#  dump the LDAP contents to a LDIF file in the given directory. The exact file
#  path can be retrevied using the method ldifFile
#
#    Parameters:
#       dir - directory in which put the LDIF file
sub _dumpLdap
{
    my ($self, $dir, $slapd, $type) = @_;

    my $user  = EBox::Config::user();
    my $group = EBox::Config::group();
    my $ldifFile = $self->ldifFile($dir, $slapd, $type);

    my $slapcatCommand = $self->_slapcatCmd($ldifFile, $slapd, $type);
    my $chownCommand = "/bin/chown $user.$group $ldifFile";

    $self->_pauseAndExecute(cmds => [$slapcatCommand, $chownCommand]);
}

sub _dumpLdapData
{
    my ($self, $dir, $slapd) = @_;
    $self->_dumpLdap($dir, $slapd, 'data');
}

sub _dumpLdapConfig
{
    my ($self, $dir, $slapd) = @_;
    $self->_dumpLdap($dir, $slapd, 'config');
}

sub dumpLdapMaster
{
    my ($self, $dir) = @_;
    $self->_dumpLdapData($dir, 'master');
    $self->_dumpLdapConfig($dir, 'master');
}

sub dumpLdapReplica
{
    my ($self, $dir) = @_;
    $self->_dumpLdapConfig($dir, 'replica');
}

sub dumpLdapTranslucent
{
    my ($self, $dir) = @_;
    $self->_dumpLdapConfig($dir, 'translucent');
    $self->_dumpLdapData($dir, 'translucent');
}

sub dumpLdapFrontend
{
    my ($self, $dir) = @_;
    $self->_dumpLdapConfig($dir, 'frontend');
    $self->_dumpLdapData($dir, 'frontend');
}

# Method: _loadLdap
#
#  load all the raw LDAP data found in the LDIF file
#
#    Parameters:
#       dir - directory in which is the LDIF file
# XXX: todo add on error sub
sub _loadLdap
{
    my ($self, $dir, $slapd, $type) = @_;

    my $ldapDir  = EBox::Ldap::dataDir($slapd);
    my $ldifFile = $self->ldifFile($dir, $slapd, $type);

    my $backupCommand = $self->_backupSystemDirectory();
    my $rmCommand = $self->_rmLdapDirCmd($ldapDir);
    my $slapaddCommand = $self->_slapaddCmd($ldifFile, $slapd, $type);
    my $chownConfCommand = $self->_chownConfDir($slapd);
    my $chownDataCommand = $self->_chownDataDir($slapd);

    $self->_execute(
                cmds => [$backupCommand, $rmCommand,
                         $slapaddCommand, $chownConfCommand, $chownDataCommand
                        ]);
}

# Method: importLdap
#
#    import in eBox the data found in LDIF file. Import classes for the various
#    modules are used to load the data
#
#    Parameters:
#       dir - directory in which is the LDIF file
sub _importLdap
{
    my ($self, $dir, $slapd, $base) = @_;

    my $ldifFile = $self->ldifFile($dir, $slapd, $base);

    EBox::UsersAndGroups::ImportFromLdif::Engine::importLdif($ldifFile);
}

sub _importLdapData
{
    my ($self, $dir, $slapd) = @_;
    $self->_importLdap($dir, $slapd, $self->dn());
}

sub _loadLdapData
{
    my ($self, $dir, $slapd) = @_;
    $self->_loadLdap($dir, $slapd, 'data');
}

sub _loadLdapConfig
{
    my ($self, $dir, $slapd) = @_;
    EBox::Sudo::root("rm -rf " . confDir($slapd));
    EBox::Sudo::root("mkdir " . confDir($slapd));

    #set new password before restoring the config tree
    my $ldifFile = $self->ldifFile($dir, $slapd, 'config');
    my $content = read_file($ldifFile);
    $content =~ s/\n //gms;
    my $pass = $self->getPassword();
    $content =~ s/credentials=".*?"/credentials="$pass"/g;
    $content =~ s/^olcRootPW:.*$/olcRootPW: $pass/mg;
    write_file($ldifFile, $content);
    $self->_loadLdap($dir, $slapd, 'config');
}

sub restoreLdapMaster
{
    my ($self, $dir) = @_;
    $self->_loadLdapConfig($dir, 'master');
    my $ldifFile = $self->ldifFile($dir, 'master', 'data');
    my $content = read_file($ldifFile);
    my $passline = 'userPassword: ' . $self->getPassword();
    $content =~ s/(^dn: cn=ebox,.*?)userPassword:.*?$/$1$passline/ms;
    write_file($ldifFile, $content);
    $self->_loadLdapData($dir, 'master');
}

sub restoreLdapReplica
{
    my ($self, $dir) = @_;
    $self->_loadLdapConfig($dir, 'replica');
}

sub restoreLdapTranslucent
{
    my ($self, $dir) = @_;
    $self->_loadLdapConfig($dir, 'translucent');
    $self->_loadLdapData($dir, 'translucent');
}

sub restoreLdapFrontend
{
    my ($self, $dir) = @_;
    $self->_loadLdapConfig($dir, 'frontend');
    $self->_loadLdapData($dir, 'frontend');
}

sub _chownConfDir
{
    my ($self, $slapd) = @_;
    return 'chown -R '  . LDAP_USER . ':' . LDAP_GROUP . ' ' . confDir($slapd);
}

sub _chownDataDir
{
    my ($self, $slapd) = @_;
    return 'chown -R '  . LDAP_USER . ':' . LDAP_GROUP . ' ' . dataDir($slapd);
}

sub _slapcatCmd
{
    my ($self, $ldifFile, $slapd, $type) = @_;

    my $base;
    if ($type eq 'config') {
        $base = 'cn=config';
    } else {
        $base = $self->dn();
    }
    return  "/usr/sbin/slapcat -F " . confDir($slapd) . " -b '$base' > $ldifFile";
}

sub _slapaddCmd
{
    my ($self, $ldifFile, $slapd, $type) = @_;
    my $base;
    my $options = "";
    #disable schema checking if we are loading a translucent dump
    if ($slapd eq 'translucent') {
        $options = "-s";
    }
    if ($type eq 'config') {
        $base = 'cn=config';
    } else {
        my $fd;
        open($fd, $ldifFile);
        my $line = <$fd>;
        chomp($line);
        my @parts = split(/ /, $line);
        $base = $parts[1];
    }
    return  "/usr/sbin/slapadd -c $options -F " . confDir($slapd) .  " -b '$base' < $ldifFile";
}

sub _rmLdapDirCmd
{
    my ($self, $ldapDir)   = @_;
    $ldapDir .= '/*' if defined $ldapDir ;

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

sub _execute
{
    my ($self, %params) = @_;
    my @cmds = @{ $params{cmds}  };
    my $onError = $params{onError};

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
    };
}

1;
