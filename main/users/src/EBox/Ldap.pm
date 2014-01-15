# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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
use base 'EBox::LDAPBase';

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Gettext;

use Net::LDAP;
use Net::LDAP::LDIF;
use Net::LDAP::Util qw(ldap_error_name);

use TryCatch::Lite;
use Apache2::RequestUtil;
use Time::HiRes;

use constant LDAPI         => "ldapi://%2fvar%2frun%2fslapd%2fldapi";
use constant LDAP          => "ldap://127.0.0.1";
use constant CONF_DIR      => '/etc/ldap/slapd.d';

# Singleton variable
my $_instance = undef;

# Method: instance
#
#   Return a singleton instance of this class
#
# Returns:
#
#   object of class <EBox::Ldap>
sub instance
{
    my ($class) = @_;

    unless(defined($_instance)) {
        $_instance = $class->_new_instance();
    }

    return $_instance;
}

sub connected
{
    my ($self) = @_;
    if ($self->{ldap}) {
        # Workaround to detect if connection is broken and force reconnection
        my $mesg = $self->{ldap}->search(
                base   => '',
                scope => 'base',
                filter => "(cn=*)",
                );
        if (ldap_error_name($mesg) ne 'LDAP_SUCCESS' ) {
            $self->{ldap}->unbind;
            return 0;
        }

        return 1;
    }

    return 0;
}

# Method: connection
#
#   Return the Net::LDAP connection used by the module
#
# Exceptions:
#
#   Internal - If connection can't be created
#
# Override:
#   EBox::LDAPBase::connection
#
sub connection
{
    my ($self) = @_;

    if (not $self->connected()) {
        $self->{ldap} = $self->anonymousLdapCon();

        my ($dn, $pass);
        my $auth_type = undef;
        try {
            my $r = Apache2::RequestUtil->request();
            $auth_type = $r->auth_type;
        } catch {
        }

        if (defined $auth_type and
            $auth_type eq 'EBox::UserCorner::Auth') {
            eval "use EBox::UserCorner::Auth";
            if ($@) {
                throw EBox::Exceptions::Internal("Error loading class EBox::UserCorner::Auth: $@")
            }
            my $credentials = undef;
            try {
                $credentials = EBox::UserCorner::Auth->credentials();
            } catch (EBox::Exceptions::DataNotFound $e) {
                # The user is not yet authenticated, we fall back to the default credentials to allow LDAP searches.
                my $userCornerMod = EBox::Global->modInstance('usercorner');
                $credentials = {
                    userDN => $userCornerMod->roRootDn(),
                    pass => $userCornerMod->getRoPassword()
                };
            }
            $dn = $credentials->{'userDN'};
            $pass = $credentials->{'pass'};
        } else {
            $dn = $self->rootDn();
            $pass = $self->getPassword();
        }
        safeBind($self->{ldap}, $dn, $pass);
    }

    return $self->{ldap};
}

# Method: url
#
#  Return the URL or parameter to create a connection with this LDAP
#
# Override: EBox::LDAPBase::url
#
sub url
{
    return LDAPI;
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

    unless (defined $self->{dn}) {
        my $ldap = $self->anonymousLdapCon();
        $ldap->bind();
        my $dse = $ldap->root_dse();

        # get naming Contexts
        my @contexts = $dse->get_value('namingContexts');

        # FIXME: LDAP tree may have multiple naming Contexts (forest), we don't support it right now, we always pick the
        # first one we get.
        if ($#contexts >= 1) {
            EBox::warn("Zentyal doesn't support 'forests', we will just work with the tree '$contexts[0]'");
        }

        $self->{dn} = $contexts[0];
    }
    return defined $self->{dn} ? $self->{dn} : '';
}

# Method: clearConn
#
#       Closes LDAP connection and clears DN cached value
#
# Override: EBox::LDAPBase::clearConn
#
sub clearConn
{
    my ($self) = @_;

    $self->SUPER::clearConn();

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

# XXX maybe use clearConn instead?
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
            # TODO: Review this code, with multiou this may not be true anymore!
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

# Method: userBindDN
#
#  given a plain user name, it return the argument needed to bind to the
#  directory which that user, normally a DN
#
# Parametes:
#        user - plain username
#
# Returns:
#   DN or other token to use for binding to the directory
sub userBindDN
{
    my ($self, $user) = @_;

    return "uid=$user," . EBox::Users::User::defaultContainer()->dn();
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

    $self->connection();
    my $rootdse = $self->{ldap}->root_dse();
    if ($rootdse->supported_extension('1.3.6.1.4.1.4203.1.11.1')) {
        # Update the password using the LDAP extension will update the kerberos keys also
        # if the smbk5pwd module and its overlay are loaded
        require Net::LDAP::Extension::SetPassword;
        my $mesg = $self->{ldap}->set_password(user => $dn,
                                               oldpasswd => $oldPasswd,
                                               newpasswd => $newPasswd);
        $self->_errorOnLdap($mesg, $dn);
    } else {
        my $mesg = $self->{ldap}->modify( $dn,
                        changes => [ delete => [ userPassword => $oldPasswd ],
                        add     => [ userPassword => $newPasswd ] ]);
        $self->_errorOnLdap($mesg, $dn);
    }
}

sub connectWithKerberos
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Internal LDAP does not support this connection method');
}

1;
