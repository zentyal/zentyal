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
use EBox::UserCorner;
use EBox::Model::ModelManager;

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
        $pass = '';
        my $letters = 'abcdefghijklmnopqrstuvwxyz';
        my @chars= split(//, $letters . uc($letters) .
            '-+/.0123456789');
        for my $i (1..16) {
            $pass .= $chars[int(rand (scalar(@chars)))];
        }
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

# Setup a master
sub master
{
    my $pass = new_pass();

    my $model = EBox::Model::ModelManager->instance()->model('Mode');
    my $dn = $model->dnValue();

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

    EBox::Sudo::root("ldapadd -H 'ldapi://' -Y EXTERNAL -c -f " .
        EBox::Config::tmp() . "slapd-master.ldif");

    EBox::Sudo::root("ldapadd -H 'ldapi://' -Y EXTERNAL -c -f " .
        EBox::Config::tmp() . "slapd-master-db.ldif");

    my $users = EBox::Global->modInstance('users');

	my $defaultGroup = $users->defaultGroup();
	$users->addGroup($defaultGroup, 'All users', 1);

    EBox::Sudo::root("invoke-rc.d slapd restart");

    createJournalsDirs();
}

# create parent dirs for slave's journals 
sub createJournalsDirs
{
    my $users = EBox::Global->modInstance('users');
    my $journalDirs   = $users->_journalsDir();
    (-d $journalDirs) or EBox::Sudo::command("mkdir -p $journalDirs");

    my $usercornerDir = EBox::UserCorner::usercornerdir() .
                        "userjournal";
    if (not -d $usercornerDir) {
        EBox::Sudo::root("mkdir -p $usercornerDir");
        EBox::Sudo::root("chown ebox.ebox $usercornerDir");
    }

}


1;
