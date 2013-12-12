# Copyright (C) 2004-2007 Warp Networks S.L
# Copyright (C) 2008-2012 Zentyal S.L.
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
use strict;
use warnings;

package EBox::Ldap;

use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;

use EBox::Gettext;

use Net::LDAP;
use Net::LDAP::Constant;
use Net::LDAP::Message;
use Net::LDAP::Search;
use Net::LDAP::LDIF;
use Net::LDAP qw(LDAP_SUCCESS);
use Net::LDAP::Util qw(ldap_error_name);

use Data::Dumper;
use Error qw(:try);
use File::Slurp qw(read_file write_file);
use Apache2::RequestUtil;
use POSIX;
use Time::HiRes;

use constant LDAPI         => "ldapi://%2fvar%2frun%2fslapd%2fldapi";
use constant LDAP          => "ldap://127.0.0.1";
use constant CONF_DIR      => '/etc/ldap/slapd.d';
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
        $self->{ldap} = $self->anonymousLdapCon();

        my ($dn, $pass);
        my $auth_type = undef;
        try {
            my $r = Apache2::RequestUtil->request();
            $auth_type = $r->auth_type;
        } catch Error with {};

        if (defined $auth_type and
            $auth_type eq 'EBox::UserCorner::Auth') {
            eval "use EBox::UserCorner::Auth";
            if ($@) {
                throw EBox::Exceptions::Internal("Error loading class EBox::UserCorner::Auth: $@")
            }
            my $credentials = EBox::UserCorner::Auth->credentials();
            my $users = EBox::Global->modInstance('users');
            $dn = $users->userDn($credentials->{'user'});
            $pass = $credentials->{'pass'};
        } else {
            $dn = $self->rootDn();
            $pass = $self->getPassword();
        }
        safeBind($self->{ldap}, $dn, $pass);
    }
    return $self->{ldap};
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
    my $ldap = EBox::Ldap::safeConnect(LDAPI);
    return $ldap;
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
#       External - If password can't be read
sub getPassword
{
    my ($self) = @_;

    unless (defined($self->{password})) {
        my $path = EBox::Config->conf() . "ldap.passwd";
        open(PASSWD, $path) or
            throw EBox::Exceptions::External('Could not get LDAP password');

        my $pwd = <PASSWD>;
        close(PASSWD);

        $pwd =~ s/[\n\r]//g;
        $self->{password} = $pwd;
    }
    return $self->{password};
}

# Method: getRoPassword
#
#   Returns the password of the read only privileged user
#   used to connect to the LDAP directory with read only
#   permissions
#
# Returns:
#
#       string - password
#
# Exceptions:
#
#       External - If password can't be read
#
sub getRoPassword
{
    my ($self) = @_;

    unless (defined($self->{roPassword})) {
        my $path = EBox::Config::conf() . 'ldap_ro.passwd';
        open(PASSWD, $path) or
            throw EBox::Exceptions::External('Could not get LDAP password');

        my $pwd = <PASSWD>;
        close(PASSWD);

        $pwd =~ s/[\n\r]//g;
        $self->{roPassword} = $pwd;
    }
    return $self->{roPassword};
}

# Method: dn
#
#       Returns the base DN (Distinguished Name)
#
# Returns:
#
#       string - DN
#
sub dn
{
    my ($self) = @_;
    if(!defined($self->{dn})) {
        my $ldap = $self->anonymousLdapCon();
        $ldap->bind();

        my %args = (
            'base' => '',
            'scope' => 'base',
            'filter' => '(objectclass=*)',
            'attrs' => ['namingContexts']
        );
        my $result = $ldap->search(%args);
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
    delete $self->{ldap};
    delete $self->{password};
}

# Method: rootDn
#
#       Returns the dn of the priviliged user
#
# Returns:
#
#       string - eboxdn
#
sub rootDn
{
    my ($self, $dn) = @_;
    unless(defined($dn)) {
        $dn = $self->dn();
    }
    return 'cn=zentyal,' . $dn;
}

# Method: roRootDn
#
#       Returns the dn of the read only priviliged user
#
# Returns:
#
#       string - the Dn
#
sub roRootDn {
    my ($self, $dn) = @_;
    unless(defined($dn)) {
        $dn = $self->dn();
    }
    return 'cn=zentyalro,' . $dn;
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
        'port' => 390,
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
    my $searchArgs = {
        base => $dn,
        scope => 'base',
        filter => "(objectclass=$objectclass)"
       };
    my $msg = $self->search($searchArgs);
    _errorOnLdap($msg, $searchArgs);
    return unless ($msg->entries > 0);

    my %attrexist = map {$_ => 1} $msg->pop_entry->attributes;
    my $attrSearchArgs = {
        base => $dn,
        scope => 'base',
        attrs => ['objectClass'],
        filter => '(objectclass=*)'
       };
    $msg = $self->search($attrSearchArgs);
    _errorOnLdap($msg, $attrSearchArgs);
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
        my $deleteArgs = [ objectclass => $objectclass, %attr2del ];
        $result = $self->modify($dn, { changes =>
                [delete => $deleteArgs] });
        _errorOnLdap($msg, $deleteArgs);
    } else {
        my $deleteArgs = [ objectclass => $objectclass ];
        $result = $self->modify($dn, { changes =>
                [delete => $deleteArgs] });
        _errorOnLdap($msg, $deleteArgs);
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
sub lastModificationTime
{
    my ($self, $fromTimestamp) = @_;

    my $filter = '(objectclass=*)';
    if (defined($fromTimestamp)) {
        $filter = "(&(objectclass=*)(modifyTimestamp>=$fromTimestamp))";
    }

    my $res = $self->search({base => $self->dn(), attrs => [ 'modifyTimestamp' ],
                             filter => $filter });
    # Order alphanumerically and the latest is the one whose timestamp
    # is the last one
    my @sortedEntries = $res->sorted('modifyTimestamp');
    if ( scalar(@sortedEntries) == 0) {
        # fromTimestamp given is greater than the current time, so we return 0
        return 0;
    }
    my $lastStamp = $sortedEntries[-1]->get_value('modifyTimestamp');

    # Convert to seconds since epoch
    my ($year, $month, $day, $h, $m, $s) =
      $lastStamp =~ /([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})Z/;
    return POSIX::mktime( $s, $m, $h, $day, $month -1, $year - 1900 );

}

sub _errorOnLdap
{
    my ($result, $args) = @_;

    if ($result->is_error){
        throw EBox::Exceptions::LDAP(result => $result, opArgs => $args);
    }
}

sub stop
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');
    $users->_manageService('stop');
    return  $self->refreshLdap();
}

sub start
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');
    $users->_manageService('start');
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
    my ($self, $dir, $base) = @_;
    return "$dir/$base.ldif";
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
    my ($self, $dir, $type) = @_;

    my $user  = EBox::Config::user();
    my $group = EBox::Config::group();
    my $ldifFile = $self->ldifFile($dir, $type);

    my $slapcatCommand = $self->_slapcatCmd($ldifFile, $type);
    my $chownCommand = "/bin/chown $user:$group $ldifFile";
    EBox::Sudo::root(
                       $slapcatCommand,
                       $chownCommand
                    );
}

sub dumpLdapData
{
    my ($self, $dir) = @_;
    $self->_dumpLdap($dir, 'data');
}

sub dumpLdapConfig
{
    my ($self, $dir) = @_;
    $self->_dumpLdap($dir, 'config');
}

sub usersInBackup
{
    my ($self, $dir) = @_;

    my @users;

    my $ldifFile = $self->ldifFile($dir, 'data');

    my $ldif = Net::LDAP::LDIF->new($ldifFile, 'r', onerror => 'undef');
    my $usersDn;

    while (not $ldif->eof()) {
        my $entry = $ldif->read_entry ( );
        if ($ldif->error()) {
           EBox::error("Error reading LDIOF file $ldifFile: " . $ldif->error() .
                       '. Error lines: ' .  $ldif->error_lines());
        } else {
            my $dn = $entry->dn();
            if (not defined $usersDn) {
                # first entry, use it to fetch the DN
                $usersDn = 'ou=Users,' . $dn;
                next;
            }

            # in zentyal users are identified by DN, not by objectclass
            if ($dn =~ /$usersDn$/) {
                push @users, $entry->get_value('uid');
            }
        }
    }
    $ldif->done();

    return \@users;
}

sub _slapcatCmd
{
    my ($self, $ldifFile, $type) = @_;

    my $base;
    if ($type eq 'config') {
        $base = 'cn=config';
    } else {
        $base = $self->dn();
    }
    return  "/usr/sbin/slapcat -F " . CONF_DIR . " -b '$base' > $ldifFile";
}

sub safeConnect
{
    my ($ldapurl) = @_;
    my $ldap;

    local $SIG{PIPE};
    $SIG{PIPE} = sub {
       EBox::warn('SIGPIPE received connecting to LDAP');
    };

    my $reconnect;
    my $connError = undef;
    my $retries = 50;
    while (not $ldap = Net::LDAP->new($ldapurl) and $retries--) {
        if ((not defined $connError) or ($connError ne $@)) {
            $connError = $@;
            EBox::error("Couldn't connect to LDAP server $ldapurl: $connError. Retrying");
        }

        $reconnect = 1;

        my $users = EBox::Global->modInstance('users');
        $users->_manageService('start');

        Time::HiRes::sleep(0.1);
    }

    if (not $ldap) {
        throw EBox::Exceptions::External(
            __x(q|FATAL: Couldn't connect to LDAP server {url}: {error}|,
                url => $ldapurl,
                error => $connError
               )
           );
    } elsif ($reconnect) {
        EBox::info('LDAP reconnect successful');
    }

    return $ldap;
}

sub safeBind
{
    my ($ldap, $dn, $password) = @_;

    my $bind = $ldap->bind($dn, password => $password);
    unless ($bind->{resultCode} == 0) {
        throw EBox::Exceptions::External(
            'Couldn\'t bind to LDAP server, result code: ' .
            $bind->{resultCode});
    }

    return $bind;
}

sub changeUserPassword
{
    my ($self, $dn, $newPasswd, $oldPasswd) = @_;

    $self->ldapCon();
    my $rootdse = $self->{ldap}->root_dse();
    if ($rootdse->supported_extension('1.3.6.1.4.1.4203.1.11.1')) {
        # Update the password using the LDAP extension will update the kerberos keys also
        # if the smbk5pwd module and its overlay are loaded
        require Net::LDAP::Extension::SetPassword;
        my $mesg = $self->{ldap}->set_password(user => $dn,
                                               oldpasswd => $oldPasswd,
                                               newpasswd => $newPasswd);
        _errorOnLdap($mesg, $dn);
    } else {
        my $mesg = $self->{ldap}->modify( $dn,
                        changes => [ delete => [ userPassword => $oldPasswd ],
                        add     => [ userPassword => $newPasswd ] ]);
        _errorOnLdap($mesg, $dn);
    }
}

1;
