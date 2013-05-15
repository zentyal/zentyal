# Copyright (C) 2010-2013 Zentyal S.L.
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

package ZentyalDesktop::Jabber;

use ZentyalDesktop::Config qw(TEMPLATES_DIR);
use ZentyalDesktop::Log;
use Text::Template;

my $logger = ZentyalDesktop::Log::logger();

sub configure
{
    my ($class, $server, $user, $data) = @_;

    $logger->debug("Jabber configure -> server: $server user: $user domain: $data->{domain}");

    my $domain = $data->{domain};

    my $config = ZentyalDesktop::Config->instance();
    my $APPDATA = $config->appData();

    my $TEMPLATES_DIR = TEMPLATES_DIR;

    # FIXME: Get user groups
    #my $gidsStr = `id -G`;
    #chomp ($gidsStr);
    #my @gids = split (' ', $gidsStr);

    # Insert group conferences in buddy list
    #my $groups = '';
    #for my $gid (@gids) {
    #    if ($gid >= 2001) {
    #        my $groupname = getgrgid($gid);
    #        $groups .= _groupStr($server, $user, $domain, $groupname);
    #    }
    #}

    my $confDir = "$APPDATA/.purple";
    mkdir ($confDir);
    $logger->debug("configuration directory: $confDir");

    my $template = new Text::Template(TYPE => FILE,
                                      SOURCE => "$TEMPLATES_DIR/pidgin/accounts.xml");
    open (my $accountsFH, '>', "$confDir/accounts.xml");
    $template->fill_in(OUTPUT => $accountsFH,
                       HASH => { user => $user,
                                 domain => $domain,
                                 server => $server });
    close ($accountsFH);

    my $template = new Text::Template(TYPE => FILE,
                                      SOURCE => "$TEMPLATES_DIR/pidgin/blist.xml");
    open (my $blistFH, '>', "$confDir/blist.xml");
    $template->fill_in(OUTPUT => $blistFH,
                       HASH => { user => $user,
                                 domain => $domain,
                                 groups => $groups });
    close ($blistFH);
}

sub _groupStr
{
    my ($server, $user, $domain, $group) = @_;

    my $group = "<chat proto='prpl-jabber' account='$user\@$domain/zentyaluser'>\n\
\t\t\t<component name='handle'>$user</component>\n\
\t\t\t<component name='room'>$group</component>\n\
\t\t\t<component name='server'>conference.$domain</component>\n\
\t\t</chat>\n";
    return $group;
}

1;
