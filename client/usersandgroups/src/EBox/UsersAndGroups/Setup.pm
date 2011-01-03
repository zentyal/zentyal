# Copyright (C) 2009-2010 eBox Technologies S.L.
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

use Error qw(:try);

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Ldap;
use EBox::Module::Base;
use EBox::Sudo qw(:all);
use EBox::Exceptions::Internal;
use EBox::Exceptions::Sudo::Command;
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
    my $model = EBox::Model::ModelManager->instance()->model('Mode');
    my $dn = $model->dnValue();

    my @commands;
    push (@commands, 'cp ' . EBox::Config::share() .
        '/ebox-usersandgroups/slapd.default /etc/default/slapd');
    push (@commands, 'invoke-rc.d slapd restart');
    EBox::Sudo::root(@commands);

    my $pass = new_pass();
    my $tmp = EBox::Config::tmp();

    EBox::Module::Base::writeConfFileNoCheck(
        "$tmp/slapd-master.ldif",
        'usersandgroups/slapd-master.ldif.mas',
        [
          'dn' => $dn,
          'password' => $pass
        ]);

    EBox::Module::Base::writeConfFileNoCheck(
        "$tmp/slapd-master-db.ldif",
        'usersandgroups/slapd-master-db.ldif.mas',
        [
          'dn' => $dn,
          'password' => $pass
        ]);

    @commands = ();
    push (@commands,
        "ldapadd -H 'ldapi://' -Y EXTERNAL -c -f $tmp/slapd-master.ldif");
    push (@commands,
        "ldapadd -H 'ldapi://' -Y EXTERNAL -c -f $tmp/slapd-master-db.ldif");

    try {
        EBox::Sudo::root(@commands);
    } catch EBox::Exceptions::Sudo::Command with {
        my $exception = shift;
        EBox::warn('Trying to setup master ldap failed, exit value: ' .
            $exception->exitValue());
    };

    createDefaultGroupIfNeeded();

    createJournalsDirs();
}

sub createDefaultGroupIfNeeded
{
    my $users = EBox::Global->modInstance('users');
    my $defaultGroup = $users->defaultGroup();
    unless ($users->groupExists($defaultGroup)) {
        $users->addGroup($defaultGroup, 'All users', 1);
    }
}

# create parent dirs for slave's journals
sub createJournalsDirs
{
    my $users = EBox::Global->modInstance('users');
    my $journalDirs = $users->_journalsDir();
    my @commands;

    unless (-d $journalDirs) {
        push (@commands, "mkdir -p $journalDirs");
    }

    my $usercornerDir = EBox::UserCorner::usercornerdir() . "userjournal";
    unless (-d $usercornerDir) {
        push (@commands, "mkdir -p $usercornerDir");
        push (@commands, "chown ebox:ebox $usercornerDir");
    }
    if (@commands) {
        EBox::Sudo::root(@commands);
    }
}

1;
