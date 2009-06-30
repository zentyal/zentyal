# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::UsersAndGroups::Setup;

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Ldap;
use EBox::Module::Base;
use EBox::Sudo qw(:all);
use EBox::Exceptions::Internal;

use constant LDAPCONFDIR    => '/etc/ldap/';

sub new_pass {
    # Create a new LDAP password for our eBox admin
    my $LDAP_PWD_FILE = EBox::Config::conf() . 'ebox-ldap.passwd';

    my $pass;
    my $newpass = undef;
    if ( -s $LDAP_PWD_FILE ) {
        my $pwdfile;
        my $fd;
        unless (open ($fd, "<$LDAP_PWD_FILE")) {
            throw EBox::Exceptions::External("Can't open $LDAP_PWD_FILE");
        }
        $pass = <$fd>;
        close($fd)
    } else {
        $pass = 'ebox' . rand((2**50));
        $newpass = 1;
    }

    if ($newpass) {
        my $fd;
        unless (open ($fd, ">$LDAP_PWD_FILE")) {
                throw EBox::Exceptions::External("Can't open $LDAP_PWD_FILE");
        }
        print $fd $pass;
        close($fd);
        unless (chmod (0400, $LDAP_PWD_FILE)) {
                throw EBox::Exceptions::External("Can't chmod $LDAP_PWD_FILE");
        }
        my ($login,$pass,$uid,$gid) = getpwnam('ebox');
        unless (chown($uid, $gid, $LDAP_PWD_FILE)) {
                throw EBox::Exceptions::External("Can't chown $LDAP_PWD_FILE");
        }
    }
    return $pass;
}

# Function stolen from slapd.config in slapd package
sub GenRandom {
      my ($len) = @_;
      my $char;
      my $data;
      my @chars;;
      @chars = split(//, "abcdefghijklmnopqrstuvwxyz"
                       . "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");

      open(RD, "</dev/urandom") or die "Failed to open random source";
      $data = "";
      while ($len--) {
        read(RD, $char, 1) == 1 or die "Failed to read random data";
        $data .= $chars[ord($char) % @chars];
      }
      close(RD);
      return $data;
}

sub update_acls
{
    my ($dn, $pass) = @_;

    my $ldap = Net::LDAP->new("ldap://127.0.0.1");
    $ldap->bind("cn=admin,cn=config", password => $pass);

    my $rootdn = "cn=admin,$dn";
    my $eboxdn = "cn=ebox,$dn";

    $dn = 'olcDatabase={1}hdb,cn=config';

    my $result = $ldap->search(
        'base' => $dn,
        'scope' => 'base',
        'filter' => '(objectclass=*)',
        'attrs' => ['olcAccess']
    );
    my $entry = ($result->entries)[0];
    my $attr = ($entry->attributes)[0];
    my @new_acls = map {
        s/(by dn="$rootdn" write)/$1 by dn="$eboxdn" write/; $_
    } $entry->get_value($attr);

    my %args = (
        replace => [ 'olcAccess' => \@new_acls]
    );
    $ldap->modify($dn, %args);
}

# Setup a master
sub master
{
    my ($ldappass) = @_;

    my $ldap = Net::LDAP->new("ldap://127.0.0.1");
    my $result = $ldap->bind('cn=admin,cn=config', 'password' => $ldappass);
    if ($result->is_error()) {
        throw EBox::Exceptions::External(__("Can't bind to LDAP with the provided password"));
    }
    my %args = (
        'base' => '',
        'scope' => 'base',
        'filter' => '(objectclass=*)',
        'attrs' => ['namingContexts']
    );
    $result = $ldap->search(%args);
    my $entry = ($result->entries)[0];
    my $attr = ($entry->attributes)[0];
    my $dn = $entry->get_value($attr);

    EBox::Sudo::root("cp " . EBox::Config::share() . "/ebox-usersandgroups/slapd.default /etc/default/slapd");
    EBox::Sudo::root("invoke-rc.d slapd restart");

    my $pass = new_pass();

    EBox::Module::Base::writeConfFileNoCheck(EBox::Config::tmp() .
        'slapd-master.ldif',
        'usersandgroups/slapd-master.ldif.mas',
        [
          'dn' => $dn,
          'password' => $pass
        ]);

    EBox::Module::Base::writeConfFileNoCheck(EBox::Config::tmp() .
        'slapd-master-db.ldif',
        'usersandgroups/slapd-master-db.ldif.mas',
        [
          'dn' => $dn,
          'password' => $pass
        ]);

    EBox::Sudo::command("ldapadd -c -x -D 'cn=admin,cn=config' -f " .
        EBox::Config::tmp() . "slapd-master.ldif -w $ldappass");

    EBox::Sudo::command("ldapadd -c -x -D 'cn=admin,$dn' -f " .
        EBox::Config::tmp() . "slapd-master-db.ldif -w $ldappass");

    update_acls($dn,$ldappass);

    my $users = EBox::Global->modInstance('users');

	my $defaultGroup = $users->defaultGroup();
	$users->addGroup($defaultGroup, 'All users', 1);

    setupSyncProvider();
    EBox::Sudo::root("invoke-rc.d slapd restart");
}

sub setupSyncProvider
{
    # add indexes for entryCNS and entryUUID
    my $dn = 'olcDatabase={1}hdb,cn=config';
    my %args = (
        replace => [ 'olcDbIndex' => ['objectclass eq',
                                      'entryCSN eq',
                                      'entryUUID eq'] ],
    );
}

1;
