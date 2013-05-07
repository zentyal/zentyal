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

package ZentyalDesktop::Services::Mail;

use ZentyalDesktop::Config qw(SKEL_DIR);

use Text::Template;

sub configure
{
    my ($class, $server, $user, $data) = @_;

    my $mailAccount = $data->{account};

    # Escape @ for evolution conf
    my $accountEscaped = $mailAccount;
    $accountEscaped =~ s/@/%40/;

    my $HOME = $ENV{HOME};

    my $config = ZentyalDesktop::Config->instance();
    my $protocol = $config->mailProtocol();
    my $useSSL = $config->mailSSL();

    # Evolution configuration

    my $template = new Text::Template(SOURCE => SKEL_DIR . '/evolution.gconf');

    my $EVOLUTIONCONF = "$HOME/evolution.gconf";
    open (my $confFH, '>', $EVOLUTIONCONF);

    $template->fill_in(OUTPUT => $confFH,
                       HASH => { user => $user,
                                 accountEscaped => $accountEscaped,
                                 mailAccount => $mailAccount,
                                 server => $server,
                                 protocol => $protocol,
                                 useSSL => $useSSL });
    close ($confFH);

    system ("gconftool --load $EVOLUTIONCONF");

    unlink ($EVOLUTIONCONF);
}

1;
