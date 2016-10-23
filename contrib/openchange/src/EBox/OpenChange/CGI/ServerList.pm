# Copyright (C) 2013 Zentyal S.L.
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

package EBox::OpenChange::CGI::ServerList;

use base 'EBox::CGI::Base';

use EBox;
use EBox::Global;
use EBox::Gettext;

use TryCatch;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title'    => 'none',
                                  'template' => 'none',
                                  @_);
    bless ($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    try {
        my $data = '';

        my $servers = [];
        my $users = EBox::Global->modInstance('samba');
        my $ldb = $users->ldap();
        my $rootDN = $ldb->dn();
        my $defaultNC = $ldb->rootDse->get_value('defaultNamingContext');
        my $dnsDomain = join('.', grep(/.+/, split(/,?DC=/, $defaultNC)));

        my $result = $ldb->search({
            base => "CN=Servers,CN=First Administrative Group,CN=Administrative Groups,CN=First Organization,CN=Microsoft Exchange,CN=Services,CN=Configuration,$rootDN",
            scope => 'one',
            filter => '(objectClass=msExchExchangeServer)',
            attrs => ['name']});
        if ($result->count() <= 0) {
            my $name = __('No servers found');
            $data .= qq{<li><span>$name</span></li>\n};
        } else {
            foreach my $entry ($result->entries()) {
                my $name = lc ($entry->get_value('name') . ".$dnsDomain");
                my $addr = $entry->get_value('');
                $data .= qq{<li><span>$name</span>};
                if (defined $addr and length $addr) {
                    $data .= qq{<span class="orange"> | $addr</span>}
                }
                $data .= qq{<button data-server="$name" class="btn btn-small force-right select-server-button"> select</button></li>\n};
            }
        }
        $self->{json} = {
            value => $data,
            type => 'good',
        };
    } catch ($error) {
        $self->{json} = {
            value => qq{<li><span class="red">$error</span></li>},
            type => 'error',
        };
    }
}

1;
