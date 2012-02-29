# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::Ldb;

use strict;
use warnings;

#use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
#use EBox::Exceptions::Internal;
#use EBox::Model::ModelManager;
use EBox::Sudo;

use EBox::Gettext;

use MIME::Base64;
use Encode qw(decode encode);

use Net::LDAP;
use Net::LDAP::Util qw(ldap_error_name);

use Data::Dumper;
#use Encode qw( :all );
#use Error qw(:try);
#use File::Slurp qw(read_file write_file);
#use Apache2::RequestUtil;
#use POSIX;

#use constant LDAPI         => "ldapi://%2fvar%2frun%2fslapd%2fldapi";
use constant LDAP          => "ldap://127.0.0.1:389";
#use constant SLAPDCONFFILE => "/etc/ldap/slapd.conf";
#use constant DATA_DIR      => '/var/lib/ldap';
#use constant LDAP_USER     => 'openldap';
#use constant LDAP_GROUP    => 'openldap';

# Singleton variable
my $_instance = undef;

sub _new_instance
{
    my $class = shift;

    my $self = {};
    $self->{ldb} = undef;
    bless($self, $class);
    return $self;
}

# Method: instance
#
#   Return a singleton instance of class <EBox::Ldb>
#
# Returns:
#
#   object of class <EBox::Ldb>
sub instance
{
    my ($self, %opts) = @_;

    unless(defined($_instance)) {
        $_instance = EBox::Ldb->_new_instance();
    }

    return $_instance;
}

# Method: ldbCon
#
#       Returns the Net::LDAP connection used by the module
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
    if ($self->{ldb}) {
        my $mesg = $self->{ldb}->search(
                base   => '',
                scope => 'base',
                filter => "(cn=*)",
                );
        if (ldap_error_name($mesg) ne 'LDAP_SUCCESS' ) {
            $self->{ldb}->unbind;
            $reconnect = 1;
        }
    }

    if ((not defined $self->{ldb}) or $reconnect) {
        $self->{ldb} = $self->anonymousLdapCon();

#        my $global = EBox::Global->getInstance();
        my ($dn, $pass);
#        my $auth_type = undef;
#        try {
#            my $r = Apache2::RequestUtil->request();
#            $auth_type = $r->auth_type;
#        } catch Error with {};

#        if ((not defined($auth_type)) or ($auth_type eq 'EBox::Auth')) {
            $dn = $self->rootDn();
            $pass = $self->getPassword();
#        } elsif ($auth_type eq 'EBox::UserCorner::Auth') {
#            eval "use EBox::UserCorner::Auth";
#            if ($@) {
#                throw EBox::Exceptions::Internal("Error loading class EBox::UserCorner::Auth: $@")
#            }
#            my $credentials = EBox::UserCorner::Auth->credentials();
#            my $users = EBox::Global->modInstance('users');
#            $dn = $users->userDn($credentials->{'user'});
#            $pass = $credentials->{'pass'};
#        } else {
#            throw EBox::Exceptions::Internal("Unknown auth_type: $auth_type");
#        }
        safeBind($self->{ldb}, $dn, $pass);
    }
    return $self->{ldb};
}


# Method: anonymousLdapCon
#
#       returns a LDAP connection without any binding
#
# Returns:
#
#       An object of class Net::LDAP
#
# Exceptions:
#
#       Internal - If connection can't be created
sub anonymousLdapCon
{
    my ($self) = @_;
    my $ldap = EBox::Ldap::safeConnect(LDAP);
    return $ldap;
}


# Method: getPassword
#
#       Returns the password used to connect to the LDB directory
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
        my $samba = EBox::Global->modInstance('samba');
        my $pwd = $samba->administratorPassword();
#        my $path = EBox::Config->conf . "/samba-admin.passwd";
#        open(PASSWD, $path) or
#            throw EBox::Exceptions::Internal("Could not open $path to " .
#                    "get the administrator password");
#        my $pwd = <PASSWD>;
#        close(PASSWD);

        $pwd =~ s/[\n\r]//g;
        $self->{password} = $pwd;
    }
    return $self->{password};
}

#sub getSlavePassword
#{
#    my ($self) = @_;
#
#    my $path = EBox::Config->conf . "/ebox-ldap.passwd";
#    open(PASSWD, $path) or
#        throw EBox::Exceptions::Internal("Could not open $path to " .
#            "get ldap password");
#
#    my $pwd = <PASSWD>;
#    close(PASSWD);
#
#    $pwd =~ s/[\n\r]//g;
#
#    return $pwd;
#}

# Method: rootDN
#
#   Returns the root DN of the domain (e.g. DC=yourdomain,DC=com)
#
# Returns:
#
#   string - DN
#
sub rootDN
{
    my ($self) = @_;
    if (!defined ($self->{dn})) {
        my $ldb = $self->anonymousLdapCon();
        $ldb->bind();

        my %args = (
            'base' => '',
            'scope' => 'base',
            'filter' => '(objectclass=*)',
            'attrs' => ['namingContexts']
        );
        my $result = $ldb->search(%args);
        my $entry = ($result->entries)[0];
        my $attr = ($entry->attributes)[0];
        $self->{dn} = $entry->get_value($attr);
    }
    return defined ($self->{dn}) ? $self->{dn} : '';
}

# Method: clearConn
#
#       Closes LDAP connection and clears DN cached value
#
sub clearConn
{
    my ($self) = @_;
    delete $self->{dn};
    delete $self->{ldb};
}

# Method: rootDn
#
#       Returns the dn of the priviliged user
#
# Returns:
#
#       string - admindn
#
sub rootDn {
    my ($self, $dn) = @_;
    unless (defined ($dn)) {
        $dn = $self->rootDN();
    }
    return 'CN=Administrator,CN=Users,' . $dn;
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
#sub slapdConfFile
#{
#    return SLAPDCONFFILE;
#}

# Method: ldapConf
#
#       Returns the current configuration for LDAP: 'dn', 'ldapi', 'rootdn'
#
# Returns:
#
#     hash ref  - holding the keys 'dn', 'ldapi', 'ldap', and 'rootdn'
#
#sub ldapConf {
#    my ($self) = @_;
#
#    my $conf = {
#        'dn'     => $self->rootDN(),
#        'ldapi'  => LDAPI,
#        'ldap'   => LDAP,
#        'port' => 390,
#        'replicaport' => 1389,
#        'translucentport' => 1390,
#        'rootdn' => $self->rootDn(),
#    };
#    return $conf;
#}

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
#
sub search # (args)
{
    my ($self, $args) = @_;

    $self->ldapCon();
#    #FIXME: this was added to deal with a problem where an object wouldn't be
#    #returned if attributes were required but objectclass wasn't required too
#    #it's apparently working now, so it's commented, remove it if it works
##    if (exists $args->{attrs}) {
##        my %attrs = map { $_ => 1 } @{$args->{attrs}};
##        unless (exists $attrs{objectClass}) {
##                push (@{$args->{attrs}}, 'objectClass');
##        }
##    }
    my $result = $self->{ldb}->search(%{$args});
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
#sub modify
#{
#    my ($self, $dn, $args) = @_;
#
#    $self->ldapCon;
#    my $result = $self->{ldap}->modify($dn, %{$args});
#    _errorOnLdap($result, $args);
#    return $result;
#}

# Method: delete
#
#       Performs a deletion  in the LDAP directory using Net::LDAP.
#
# Parameters:
#
#       dn - dn to delete
#
# Exceptions:
#
#       Internal - If there is an error during the search
#sub delete
#{
#    my ($self, $dn) = @_;
#
#    $self->ldapCon;
#    my $result =  $self->{ldap}->delete($dn);
#    _errorOnLdap($result, $dn);
#    return $result;
#}

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
#sub add # (dn, args)
#{
#    my ($self, $dn, $args) = @_;
#
#    $self->ldapCon;
#    my $result =  $self->{ldap}->add($dn, %{$args});
#    _errorOnLdap($result, $args);
#    return $result;
#}

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
#sub delObjectclass # (dn, objectclass);
#{
#    my ($self, $dn, $objectclass) = @_;
#
#    my $schema = $self->ldapCon->schema();
#    my $msg = $self->search(
#            { base => $dn, scope => 'base',
#            filter => "(objectclass=$objectclass)"
#            });
#    _errorOnLdap($msg);
#    return unless ($msg->entries > 0);
#
#    my %attrexist = map {$_ => 1} $msg->pop_entry->attributes;
#
#    $msg = $self->search(
#            { base => $dn, scope => 'base',
#            attrs => ['objectClass'],
#            filter => '(objectclass=*)'
#            });
#    _errorOnLdap($msg);
#    my %attrs;
#    for my $oc (grep(!/^$objectclass$/, $msg->entry->get_value('objectclass'))){
#        # get objectclass attributes
#        my @ocattrs =  map {
#            $_->{name}
#        }  ($schema->must($oc), $schema->may($oc));
#
#        # mark objectclass attributes as seen
#        foreach (@ocattrs) {
#            $attrs{$_ } = 1;
#        }
#    }
#
#    # get the attributes of the object class which will be deleted
#    my @objectAttrs = map {
#        $_->{name}
#    }  ($schema->must($objectclass), $schema->may($objectclass));
#
#
#    my %attr2del;
#    for my $attr (@objectAttrs) {
#        # Skip if the attribute belongs to another objectclass
#        next if (exists $attrs{$attr});
#        # Skip if the attribute is not stored in the object
#        next unless (exists $attrexist{$attr});
#        $attr2del{$attr} = [];
#    }
#
#    my $result;
#    if (%attr2del) {
#        $result = $self->modify($dn, { changes =>
#                [delete =>[ objectclass => $objectclass, %attr2del ] ] });
#        _errorOnLdap($msg);
#    } else {
#        $result = $self->modify($dn, { changes =>
#                [delete =>[ objectclass => $objectclass ] ] });
#        _errorOnLdap($msg);
#    }
#    return $result;
#}

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
#sub modifyAttribute # (dn, attribute, value);
#{
#    my ($self, $dn, $attribute, $value) = @_;
#
#    my %attrs = ( changes => [ replace => [ $attribute => $value ] ]);
#    $self->modify($dn, \%attrs );
#}

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
#sub setAttribute # (dn, attribute, value);
#{
#    my ($self, $dn, $attribute, $value) = @_;
#
#    my %args = (base => $dn, filter => "$attribute=*");
#    my $result = $self->search(\%args);
#    my $action = $result->count > 0 ? 'replace' : 'add';
#
#    my %attrs = ( changes => [ $action => [ $attribute => $value ] ]);
#    $self->modify($dn, \%attrs);
#}

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
#sub delAttribute # (dn, attribute);
#{
#    my ($self, $dn, $attribute, $value) = @_;
#
#    my %args = (base => $dn, filter => "$attribute=*");
#    my $result = $self->search(\%args);
#    if ($result->count > 0) {
#        my %attrs = ( changes => [ delete => [ $attribute => [] ] ]);
#        $self->modify($dn, \%attrs);
#    }
#}

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
#sub getAttribute # (dn, attribute);
#{
#    my ($self, $dn, $attribute) = @_;
#
#    my %args = (base => $dn, filter => "$attribute=*");
#    my $result = $self->search(\%args);
#
#    return undef unless ($result->count > 0);
#
#    return $result->entry(0)->get_value($attribute);
#}


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
#sub isObjectClass
#{
#    my ($self, $dn, $objectClass) = @_;
#
#
#    my %attrs = (
#            base   => $dn,
#            filter => "(objectclass=$objectClass)",
#            attrs  => [ 'objectClass'],
#            scope  => 'base'
#            );
#
#    my $result = $self->search(\%attrs);
#
#    if ($result->count ==  1) {
#        return 1;
#    }
#
#    return undef;
#}

# Method: objectClasses
#
#      return the object classes of an object
#
# Parameters:
#          dn          - the object's dn
#
#  Returns:
#    array - containing the object classes
#sub objectClasses
#{
#    my ($self, $dn) = @_;
#
#    my %attrs = (
#            base   => $dn,
#            filter => "(objectclass=*)",
#            attrs  => [ 'objectClass'],
#            scope  => 'base'
#            );
#
#    my $result = $self->search(\%attrs);
#
#    return [ $result->pop_entry()->get_value('objectClass') ];
#}

# Method: lastModificationTime
#
#     Get the last modification time for the directory
#
# Parameters:
#
#     fromTimestamp - String from timestamp to start the query from to
#                     speed up the query. If the value is greater than
#                     the LDAP last modification time, then it returns zero
#                     *Optional* Default value: undef
#
# Returns:
#
#     Int - the timestamp in seconds since epoch
#
# Example:
#
#     $ldap->lastModificationTime('20091204132422Z') => 1259955547
#
#sub lastModificationTime
#{
#    my ($self, $fromTimestamp) = @_;
#
#    my $filter = '(objectclass=*)';
#    if (defined($fromTimestamp)) {
#        $filter = "(&(objectclass=*)(modifyTimestamp>=$fromTimestamp))";
#    }
#
#    my $res = $self->search({base => $self->rootDN(), attrs => [ 'modifyTimestamp' ],
#                             filter => $filter });
#    # Order alphanumerically and the latest is the one whose timestamp
#    # is the last one
#    my @sortedEntries = $res->sorted('modifyTimestamp');
#    if ( scalar(@sortedEntries) == 0) {
#        # fromTimestamp given is greater than the current time, so we return 0
#        return 0;
#    }
#    my $lastStamp = $sortedEntries[-1]->get_value('modifyTimestamp');
#
#    # Convert to seconds since epoch
#    my ($year, $month, $day, $h, $m, $s) =
#      $lastStamp =~ /([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})Z/;
#    return POSIX::mktime( $s, $m, $h, $day, $month -1, $year - 1900 );
#
#}

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
#sub _utf8Attrs # (result)
#{
#    my ($result) = @_;
#
#    my @entries = $result->entries;
#    foreach my $attr (@{$entries[0]->{'asn'}->{'attributes'}}) {
#        my @vals = @{$attr->{vals}};
#        next unless (@vals);
#        my @utfvals;
#        foreach my $val (@vals) {
#            _utf8_on($val);
#            push @utfvals, $val;
#        }
#        $attr->{vals} = \@utfvals;
#    }
#
#    return $result;
#}
#
#sub confDir
#{
#    my ($slapd) = @_;
#    if ($slapd eq 'master') {
#        return "/etc/ldap/slapd.d";
#    } else {
#        return "/etc/ldap/slapd-$slapd.d";
#    }
#}
#
#sub dataDir
#{
#    my ($slapd) = @_;
#    if ($slapd eq 'master') {
#        return "/var/lib/ldap/";
#    } else {
#        return "/var/lib/ldap-$slapd/";
#    }
#}
#
#sub stop
#{
#    my ($self) = @_;
#    my $users = EBox::Global->modInstance('users');
#    $users->_manageService('stop');
#    return  $self->refreshLdap();
#}
#
#sub start
#{
#    my ($self) = @_;
#    my $users = EBox::Global->modInstance('users');
#    $users->_manageService('start');
#    return  $self->refreshLdap();
#}
#
#
#sub refreshLdap
#{
#    my ($self) = @_;
#
#    $self->{ldap} = undef;
#    return $self;
#}
#
#
#
#sub ldifFile
#{
#    my ($self, $dir, $conf, $base) = @_;
#    return "$dir/$conf-$base.ldif";
#}

# Method: dumpLdap
#
#  dump the LDAP contents to a LDIF file in the given directory. The exact file
#  path can be retrevied using the method ldifFile
#
#    Parameters:
#       dir - directory in which put the LDIF file
#sub _dumpLdap
#{
#    my ($self, $dir, $slapd, $type) = @_;
#
#    my $user  = EBox::Config::user();
#    my $group = EBox::Config::group();
#    my $ldifFile = $self->ldifFile($dir, $slapd, $type);
#
#    my $slapcatCommand = $self->_slapcatCmd($ldifFile, $slapd, $type);
#    my $chownCommand = "/bin/chown $user:$group $ldifFile";
#
#    $self->_execute(1, # With pause
#        cmds => [$slapcatCommand, $chownCommand]);
#}
#
#sub _dumpLdapData
#{
#    my ($self, $dir, $slapd) = @_;
#    $self->_dumpLdap($dir, $slapd, 'data');
#}
#
#sub _dumpLdapConfig
#{
#    my ($self, $dir, $slapd) = @_;
#    $self->_dumpLdap($dir, $slapd, 'config');
#}
#
#sub dumpLdapMaster
#{
#    my ($self, $dir) = @_;
#    $self->_dumpLdapData($dir, 'master');
#    $self->_dumpLdapConfig($dir, 'master');
#}
#
#sub dumpLdapReplica
#{
#    my ($self, $dir) = @_;
#    $self->_dumpLdapConfig($dir, 'replica');
#}
#
#sub dumpLdapTranslucent
#{
#    my ($self, $dir) = @_;
#    $self->_dumpLdapConfig($dir, 'translucent');
#    $self->_dumpLdapData($dir, 'translucent');
#}
#
#sub dumpLdapFrontend
#{
#    my ($self, $dir) = @_;
#    $self->_dumpLdapConfig($dir, 'frontend');
#    $self->_dumpLdapData($dir, 'frontend');
#}

# Method: _loadLdap
#
#  load all the raw LDAP data found in the LDIF file
#
#    Parameters:
#       dir - directory in which is the LDIF file
# XXX: todo add on error sub
#sub _loadLdap
#{
#    my ($self, $dir, $slapd, $type) = @_;
#
#    my $ldapDir  = EBox::Ldap::dataDir($slapd);
#    my $ldifFile = $self->ldifFile($dir, $slapd, $type);
#
#    my $backupCommand = $self->_backupSystemDirectory();
#    my $mkCommand = $self->_mkLdapDirCmd($ldapDir);
#    my $rmCommand = $self->_rmLdapDirCmd($ldapDir);
#    my $slapaddCommand = $self->_slapaddCmd($ldifFile, $slapd, $type);
#    my $chownConfCommand = $self->_chownConfDir($slapd);
#    my $chownDataCommand = $self->_chownDataDir($slapd);
#
#    $self->_execute(0, # Without pause
#        cmds => [$backupCommand, $mkCommand, $rmCommand, $slapaddCommand,
#            $chownConfCommand, $chownDataCommand]);
#}
#
#sub _loadLdapData
#{
#    my ($self, $dir, $slapd) = @_;
#    $self->_loadLdap($dir, $slapd, 'data');
#}
#
#sub _loadLdapConfig
#{
#    my ($self, $dir, $slapd) = @_;
#    EBox::Sudo::root("rm -rf " . confDir($slapd));
#    EBox::Sudo::root("mkdir " . confDir($slapd));
#
#    #set new password before restoring the config tree
#    my $ldifFile = $self->ldifFile($dir, $slapd, 'config');
#    my $content = read_file($ldifFile);
#    $content =~ s/\n //gms;
#    my $pass = $self->getPassword();
#    $content =~ s/credentials=".*?"/credentials="$pass"/g;
#    $content =~ s/^olcRootPW:.*$/olcRootPW: $pass/mg;
#    write_file($ldifFile, $content);
#    $self->_loadLdap($dir, $slapd, 'config');
#}
#
#sub restoreLdapMaster
#{
#    my ($self, $dir) = @_;
#
#    if (-f "$dir/ldap.ldif") {
#        EBox::Sudo::root("rm -rf /var/lib/ldap/*");
#
#        my $model = EBox::Model::ModelManager->instance()->model('Mode');
#        my $dn = $model->dnValue();
#        my @parts = split(/,/, $dn);
#        my $dc = (split(/=/, $parts[0]))[1];
#
#        EBox::Sudo::root("cp $dir/ldap.ldif /var/lib/zentyal/tmp/ldap.ldif");
#        EBox::Sudo::root("sed -i -e 's/dc=ebox/$dn/' /var/lib/zentyal/tmp/ldap.ldif");
#        EBox::Sudo::root("sed -i -e 's/dc: ebox/dc: $dc/' /var/lib/zentyal/tmp/ldap.ldif");
#        EBox::Sudo::rootWithoutException("/usr/sbin/slapadd -c -F /etc/ldap/slapd.d < /var/lib/zentyal/tmp/ldap.ldif");
#        EBox::Module::Base::writeConfFileNoCheck(EBox::Config::tmp() .
#            'slapd-master-upgrade-ebox.ldif',
#            'users/slapd-master-upgrade-ebox.ldif.mas',
#            [
#                'dn' => $dn,
#                'password' => $self->getPassword()
#            ]);
#        EBox::Sudo::root('chown -R '  . LDAP_USER . ':' . LDAP_GROUP . ' /var/lib/ldap');
#        $self->start();
#        sleep(1);
#        EBox::Sudo::root("ldapadd -H 'ldapi://' -Y EXTERNAL -c -f " .
#            EBox::Config::tmp() . "slapd-master-upgrade-ebox.ldif");
#    } else {
#        $self->_loadLdapConfig($dir, 'master');
#        my $ldifFile = $self->ldifFile($dir, 'master', 'data');
#        my $content = read_file($ldifFile);
#        my $passline = 'userPassword: ' . $self->getPassword();
#        $content =~ s/(^dn: cn=ebox,.*?)userPassword:.*?$/$1$passline/ms;
#        write_file($ldifFile, $content);
#        $self->_loadLdapData($dir, 'master');
#    }
#}
#
#sub restoreLdapReplica
#{
#    my ($self, $dir) = @_;
#    $self->_loadLdapConfig($dir, 'replica');
#}
#
#sub restoreLdapTranslucent
#{
#    my ($self, $dir) = @_;
#    $self->_loadLdapConfig($dir, 'translucent');
#    $self->_loadLdapData($dir, 'translucent');
#}
#
#sub restoreLdapFrontend
#{
#    my ($self, $dir) = @_;
#    $self->_loadLdapConfig($dir, 'frontend');
#    $self->_loadLdapData($dir, 'frontend');
#}
#
#sub usersInBackup
#{
#    my ($self, $dir, $mode) = @_;
#
#    if ($mode eq 'slave') {
#        EBox::error('Not implemented: slave mode precheck for LDAP backup');
#        return [];
#    }
#
#    my @users;
#
#    my $ldifFile = $self->ldifFile($dir, 'master', 'data');
#
#    my $ldif = Net::LDAP::LDIF->new($ldifFile, 'r', onerror => 'undef');
#    my $usersDn;
#
#    while (not $ldif->eof()) {
#        my $entry = $ldif->read_entry ( );
#        if ($ldif->error()) {
#           EBox::error("Error reading LDIOF file $ldifFile: " . $ldif->error() .
#                       '. Error lines: ' .  $ldif->error_lines());
#        } else {
#            my $dn = $entry->rootDN();
#            if (not defined $usersDn) {
#                # first entry, use it to fetch the DN
#                $usersDn = 'ou=Users,' . $dn;
#                next;
#            }
#
#            # in zentyal users are identified by DN, not by objectclass
#            if ($dn =~ /$usersDn$/) {
#                push @users, $entry->get_value('uid');
#            }
#        }
#    }
#    $ldif->done();
#
#    return \@users;
#}
#
#sub _chownConfDir
#{
#    my ($self, $slapd) = @_;
#    return 'chown -R '  . LDAP_USER . ':' . LDAP_GROUP . ' ' . confDir($slapd);
#}
#
#sub _chownDataDir
#{
#    my ($self, $slapd) = @_;
#    return 'chown -R '  . LDAP_USER . ':' . LDAP_GROUP . ' ' . dataDir($slapd);
#}
#
#sub _slapcatCmd
#{
#    my ($self, $ldifFile, $slapd, $type) = @_;
#
#    my $base;
#    if ($type eq 'config') {
#        $base = 'cn=config';
#    } else {
#        $base = $self->rootDN();
#    }
#    return  "/usr/sbin/slapcat -F " . confDir($slapd) . " -b '$base' > $ldifFile";
#}
#
#sub _slapaddCmd
#{
#    my ($self, $ldifFile, $slapd, $type) = @_;
#    my $base;
#    my $options = "";
#    #disable schema checking if we are loading a translucent dump
#    if ($slapd eq 'translucent') {
#        $options = "-s";
#    }
#    if ($type eq 'config') {
#        $base = 'cn=config';
#    } else {
#        my $fd;
#        open($fd, $ldifFile);
#        my $line = <$fd>;
#        chomp($line);
#        my @parts = split(/ /, $line);
#        $base = $parts[1];
#    }
#    return  "/usr/sbin/slapadd -c $options -F " . confDir($slapd) .  " -b '$base' < $ldifFile";
#}
#
#sub _mkLdapDirCmd
#{
#    my ($self, $ldapDir)   = @_;
#
#    return "mkdir -p $ldapDir";
#}
#
#sub _rmLdapDirCmd
#{
#    my ($self, $ldapDir)   = @_;
#
#    if (defined($ldapDir)) {
#        $ldapDir .= '/*';
#        return "sh -c '/bin/rm -rf $ldapDir'";
#    } else {
#        return "true";
#    }
#}
#
#sub _backupSystemDirectory
#{
#    my ($self) = @_;
#
#    return EBox::Config::share() . '/zentyal-users/slapd.backup';
#}
#
#sub _execute
#{
#    my ($self, $pause, %params) = @_;
#    my @cmds = @{ $params{cmds} };
#    my $onError = $params{onError};
#
#    if ($pause) {
#        $self->stop();
#    }
#    try {
#        EBox::Sudo::root(@cmds);
#    }
#    otherwise {
#        my $ex = shift;
#
#        if ($onError) {
#            $onError->($self);
#        }
#
#        throw $ex;
#    }
#    finally {
#        if ($pause) {
#            $self->start();
#        }
#    };
#}

sub safeConnect
{
    my ($ldapurl) = @_;
    my $retries = 4;
    my $ldap;

    local $SIG{PIPE};
    $SIG{PIPE} = sub {
       EBox::warn('SIGPIPE received connecting to LDAP');
    };
    while (not $ldap = Net::LDAP->new($ldapurl) and $retries--) {
        my $samba = EBox::Global->modInstance('samba');
        $samba->_manageService('start');
        EBox::error("Couldn't connect to LDAP server $ldapurl, retrying");
        sleep(1);
    }

    unless ($ldap) {
        throw EBox::Exceptions::Internal(
            "FATAL: Couldn't connect to LDAP server: $ldapurl");
    }

    if ($retries < 3) {
        EBox::info('LDAP reconnect successful');
    }

    return $ldap;
}

sub safeBind
{
    my ($ldap, $dn, $password) = @_;

    my $bind = $ldap->bind($dn, password => $password);
    unless ($bind->{resultCode} == 0) {
        throw EBox::Exceptions::Internal(
            'Couldn\'t bind to LDAP server, result code: ' .
            $bind->{resultCode});
    }

    return $bind;
}

#############################################################################
## Credentials related functions                                           ##
#############################################################################

# Method: decodeKerberos
#
#   Decode the KERB_STORED_CREDENTIAL struct. This struct
#   contains the hashes of the kerberos keys. Its format
#   is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245503(v=prot.10).aspx
#
# Returns:
#
#   A hash reference with the kerberos keys
#
sub _decodeKerberos
{
    my ($self, $data) = @_;

    my $kerberosKeys = {};

    $data = pack('H*', $data); # from hex to binary
    my $format = 's x2 s s s s l a*';
    if (length ($data) > 16) {
        my ($revision, $nCredentials, $nOldCredentials, $saltLength, $maxSaltLength, $saltOffset) = unpack($format, $data);
        EBox::debug ("Kerberos info: revision '$revision', number of credentials '$nCredentials', " .
                     "number of old credentials '$nOldCredentials', salt length '$saltLength', " .
                     "salt max length '$maxSaltLength', salt offset '$saltOffset'");
        if ($revision == 3) {
            my ($saltValue) = unpack('@' . $saltOffset . 'a' . $maxSaltLength, $data);
            EBox::debug ("Salt length '$maxSaltLength', salt value '$saltValue'");

            my $offset = 16;
            for(my $i=0; $i<$nCredentials; $i++) {
                my ($keyType, $keyLength, $keyOffset) = unpack('@' . $offset . 'x8 l l l', $data);
                my ($keyValue) = unpack('@' . $keyOffset . 'a' . $keyLength, $data);
                $offset += 20;

                if ($keyType == 1) {
                    $kerberosKeys->{'dec-cbc-crc'} = $keyValue;
                }
                elsif ($keyType == 3) {
                    $kerberosKeys->{'des-cbc-md5'} = $keyValue;
                }
                EBox::debug ("Found kerberos key: type '$keyType', length '$keyLength', value '$keyValue'");
            }
        }
    }
    return $kerberosKeys;
}

# Method: decodeWDigest
#
#   Docode the WDIGEST_CREDENTIALS struct. This struct
#   contains 29 different hashes produced by combinations
#   of different elements including the sAMAccountName,
#   realm, host, etc. The format is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245502(v=prot.10).aspx
#   The list of included hashes is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245680(v=prot.10).aspx
#
# Returns:
#
#   An array reference containing the hashes
#
sub _decodeWDigest
{
    my ($self, $data) = @_;

    my $hashes = ();

    my $format = 'x4 a2 a2 x24 (a32)29';
    if (length ($data) == 960) {
        my ($version, $nHashes, @hashValues) = unpack($format, $data);
        $version = hex($version);
        $nHashes = hex($nHashes);
        EBox::debug ("WDigest info: version '$version', hash count '$nHashes'");
        if ($version == 1 and $nHashes == 29) {
            $hashes = \@hashValues;
        }
    }
    return $hashes;
}

# Method: decodeSupplementalCredentials
#
#   This method decodes the supplementalCredentials base64
#   encoded blob, called USER_PROPERTIES. The format of this
#   this struct is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245500(v=prot.10).aspx
#   The USER_PROPERTIES contains various USER_PROPERTY structs,
#   documented at:
#   http://msdn.microsoft.com/en-us/library/cc245501(v=prot.10).aspx
#
# Returns:
#
#   A hash reference containing the different hashes
#   of the user credentials in different formats
#
sub _decodeSupplementalCredentials
{
    my ($self, $user, $blob) = @_;

    my $credentials = {};
    $blob = decode_base64 ($blob);
    my $blobFormat = 'x4 L< x2 x2 x96 S< S< a*';
    if (length ($blob) > 112) {
        my ($blobLength, $blobSignature, $nProperties, $properties) = unpack ($blobFormat, $blob);
        # Check the signature. Its value must be 0x50
        if ($blobSignature == 0x50) {
            my $offset = 112;
            for (my $i=0; $i<$nProperties; $i++) {
                my ($propertyNameLength) = unpack('@' . $offset . 'S<', $blob);
                $offset += 2;

                my ($propertyValueLength) = unpack('@' . $offset . 'S<', $blob);
                $offset += 4; # 2 bytes + 2 bytes reserved

                my ($propertyName) = unpack('@' . $offset . 'a' . $propertyNameLength, $blob);
                $offset += $propertyNameLength;

                my ($propertyValue) = unpack('@' . $offset . 'a' . $propertyValueLength, $blob);
                $offset += $propertyValueLength;

                EBox::debug ("Found property '$propertyName'='$propertyValue'");
                if($propertyName eq encode('UTF-16LE', 'Primary:Kerberos')) {
                    $credentials->{'Primary:Kerberos'} = $self->_decodeKerberos($propertyValue);
                }
                elsif($propertyName eq encode('UTF-16LE', 'Primary:WDigest')) {
                    $credentials->{'Primary:WDigest'} = $self->_decodeWDigest($propertyValue);
                }
                elsif($propertyName eq encode('UTF-16LE', 'Primary:CLEARTEXT')) {
                    $credentials->{'Primary:CLEARTEXT'} = decode('UTF-16LE', pack ('H*', $propertyValue));
                }
            }
        } else {
            EBox::error ("Corrupted supplementalCredentials found on user $user");
        }
    } else {
        EBox::error ("Truncated supplementalCredentials found on user $user");
    }
    return $credentials;
}

# Method: parseLdbSearch
#
#   This method parse the output of the command ldbsearch
#
# Returns:
#
#   A hash reference containing the attributes
#   found in the command output
#
sub _parseLdbSearch
{
    my ($self, $output) = @_;
    my $retVal = {};
    $output =~ s/#.*\n//mg; # Remove comments
    $output =~ s/\n(?=\s)//g; # Fix continuation lines
    my @attributes = split(/\n/, $output); # Split attributes
    my $tmp = {};
    foreach my $attribute (@attributes) {
        my ($key, $value) = split (/: |:: /, $attribute);
        $retVal->{$key} = $value;
    }
    return $retVal;
}

# Method: getSambaCredentials
#
#   This method gets all the credentials stored in the
#   LDB for the user
#
# Parameters:
#
#   userID - The user ID (the sAMAccountName)
#
# Returns:
#
#   A hash reference containing all found credentials
#
sub getSambaCredentials
{
    my ($self, $userID) = @_;

    EBox::debug ("Getting samba credentials for user '$userID'");

    # Read credentials from ldb file, LDAP interface does not provide them
    # TODO We should write the necessary perl bindings to LDB library
    my $cmd = "ldbsearch -H /var/lib/samba/private/sam.ldb.d/" .
              uc ($self->rootDN()) . ".ldb 'samAccountName=$userID' supplementalCredentials unicodePwd";
    my $output = EBox::Sudo::root($cmd);
    my $outputJoin = join ('', @{$output});
    my $outputHash = $self->_parseLdbSearch ($outputJoin);
    my $credentials = {};
    if (exists $outputHash->{supplementalCredentials}) {
        $credentials = $self->_decodeSupplementalCredentials ($userID, $outputHash->{supplementalCredentials});
    }
    if (exists $outputHash->{unicodePwd}) {
        $credentials->{'unicodePwd'} = decode_base64 ($outputHash->{'unicodePwd'});
    }
    return $credentials;
}

#############################################################################
## LDB related functions                                                   ##
#############################################################################

# Method: getTokenGroups
#
#   Gets tokenGroups attribute from the provided DN
#
# Parameters:
#
#   objectDN - The DN of the object
#
# Returns:
#
#   The object group tokens
#
sub getTokenGroups
{
    my ($self, $objectDN) = @_;

    my $results = $self->search({
            base => $objectDN,
            scope => 'base',
            filter => '(objectCategory=*)',
            attrs => ['tokenGroups']});
    if ($results->count) {
        return $results->entry(0)->get_value('tokenGroups');
    }
}

# Method getIDBySid
#
#   Get sAMAccountName by object's SID
#
# Parameters:
#
#   objectSid - The SID of the object
#
# Returns:
#
#   The sAMAccountName of the object
#
sub getIDBySid
{
    my ($self, $objectSid) = @_;

    my $results = $self->search({
            base => '<SID=' . unpack('H*', $objectSid) . '>',
            scope => 'base',
            filter => '(objectCategory=*)',
            attrs => ['sAMAccountName']});
    if ($results->count) {
        return $results->entry(0)->get_value('sAMAccountName');
    }
}

# Method getSidById
#
#   Get SID by object's sAMAccountName
#
# Parameters:
#
#   id - The ID of the object
#
# Returns:
#
#   The SID of the object
#
sub getSidById
{
    my ($self, $objectId) = @_;

    my $results = $self->search({
            base => $self->rootDN(),
            filter => "(sAMAccountName=$objectId)",
            attrs => ['objectSid']});
    if ($results->count) {
        my $result = $results->entry(0)->get_value('objectSid');
        return pack ('H*', $result);
    } else {
        throw EBox::Exceptions::DataNotFound('sAMAccountName not found');
    }
}

# Method: getDNByID
#
#   Get DN by sAMAccountName
#
# Parameters:
#
#   ID - The object's ID
#
# Returns:
#
#   The DN of the object
#
sub getDNByID
{
    my ($self, $ID) = @_;

    my $results = $self->search({
            base => $self->rootDN(),
            filter => "(sAMAccountName=$ID)",
            attrs => ['distinguishedName']});
    if ($results->count) {
        return $results->entry(0)->get_value('distinguishedName');
    }
}

# Method: getIdByDn
#
#   Get sAMAccountName by DN
#
# Parameters:
#
#   DN - The object's DN
#
# Returns:
#
#   The ID of the object
#
sub getIdByDN
{
    my ($self, $DN) = @_;

    my $results = $self->search({
            base => $self->rootDN(),
            filter => "(dn=$DN)",
            attrs => ['sAMAccountName']}
            );
    if ($results->count) {
        return $results->entry(0)->get_value('sAMAccountName');
    }
}

# Method: getUsers
#
#   This method get all users stored in the LDB
#
# Parameters:
#
#   usersToIgnore (optional) - list of users to ignore
#   system (optional) - include system users in the result
#
# Returns:
#
#   A hash referente containing all found entries
#
sub getUsers
{
    my ($self, $usersToIgnore, $system) = @_;

    my $filter = '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200))';
    if (defined $system) {
        $filter = '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200)(!(IsCriticalSystemObject=TRUE)))';
    }
    my $users = {};
    my $result = $self->search({
            base => $self->rootDN(),
            scope  => 'sub',
            filter => $filter});
    my @entries = $result->entries;
    if (defined $usersToIgnore) {
        my %usersToIgnore = map { $_ => 1 } @{$usersToIgnore};
        foreach my $entry (@entries) {
            unless (exists $usersToIgnore{$entry->get_value('sAMAccountName')}) {
                $users->{$entry->get_value('sAMAccountName')} = $entry;
            }
        }
    }
    return $users;
}

# Method: getGroups
#
#   This method get all groups stored in the LDB
#
# Parameters:
#
#   groupsToIgnore (optional) - reference to a list containing
#       the list of users to ignore
#
# Returns:
#
#   A hash referente containing the found entries
#
sub getGroups
{
    my ($self, $groupsToIgnore, $system) = @_;

    my $filter = '(&(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002))';
    if (defined $system) {
        $filter = '(&(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002)(!(isCriticalSystemObject=TRUE)))';
    }
    my $groups = {};
    my $result = $self->search({
            base => $self->rootDN(),
            scope  => 'sub',
            filter => $filter});
    my @entries = $result->entries;
    if (defined $groupsToIgnore) {
        my %groupsToIgnore = map { $_ => 1 } @{$groupsToIgnore};
        foreach my $entry (@entries) {
            unless (exists $groupsToIgnore{$entry->get_value('sAMAccountName')}) {
                $groups->{$entry->get_value('sAMAccountName')} = $entry;
            }
        }
    }
    return $groups;
}

# Method: getGroupsOfUser
#
#   Return the groups ID that the user belongs to
#
# Parameters:
#
#   userID - the user ID
#
# Returns:
#
#   A list reference containing the groups ID
#
sub getGroupsOfUser
{
    my ($self, $userID) = @_;

    my $userDN = $self->_getDNByID($userID);
    my @groupTokens = $self->_getTokenGroups($userDN);
    my $userGroups = ();
    foreach my $tk (@groupTokens) {
        push (@{$userGroups}, $self->_getIDBySid($tk));
    }
    return $userGroups;
}

# Method: getGroupMembers
#
#   Return the users ID of the group members
#
# Parameters:
#
#   groupID - the group ID
#
# Returns:
#
#   A list reference containing the members ID
#
sub getGroupMembers
{
    my ($self, $groupID) = @_;

    my $groupDN = $self->_getDNByID($groupID);
    my @tokens = $self->_getTokenGroups($groupDN);
    my $members = ();
    foreach my $tk (@tokens) {
        push (@{$members}, $self->_getIDBySid($tk));
    }
    return $members;
}

1;
