# Copyright (C) 2006-2007 Warp Networks S.L.
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

package EBox::Config::TestStub;

use Test::MockObject;
use Perl6::Junction qw(all);
use EBox::Config;
use TryCatch;

# XXX: Derivated paths are totally decoupled from their base path (datadir, sysconfdir, localstatedir, libdir)
# possible solution 1: rewrite EBox::Config so the derivated elements use a sub to get the needed element
# possible solution 2: rewrite this package to have specialized fakes for those subs

my %config = _defaultConfig();    # this hash hold the configuration items

sub _defaultConfig
{
    my @defaultConfig;

    my @configKeys = qw(prefix etc var user group share scripts locale conf tmp passwd sessionid log logfile stubs cgi templates schemas www css images version lang modules);
    my %problematicKeys = (
        user => 'ebox',
        group => 'ebox',
    );

    foreach my $key (@configKeys) {
        my $configKeySub_r = EBox::Config->can($key);
        defined $configKeySub_r or die "Can not find $key sub in EBox::Config module";
        my $value;

        try {
            if (exists $problematicKeys{$key}) {
                $value = $problematicKeys{$key};
            } else {
                $value = $configKeySub_r->();
            }
        } catch {
            # ignore systems where configuration files are  not installed
            $value = undef;
            print "\n\nFailed: $key \n";;
        }

        push @defaultConfig, ($key => $value );
    }

    return @defaultConfig;
}

sub fake
{
    my @fakedConfig = @_;

    if (@fakedConfig > 0)  {
        setConfigKeys(@fakedConfig);
    }
    *EBox::Config::home = sub { return '/tmp/' };
}

sub _checkFakeParams
{
    my %params = @_;

}

sub unfake
{
    delete $INC{'EBox/Config.pm'};
    eval 'use EBox::Config';

    $@ and die "Error reloading EBox::Config: $@";
}

sub _checkConfigKeysParameters
{
    my %params = @_;

    # check parameters...
    if (@_ == 0) {
        die "setConfigKeys called without parameters";
    }
    my $allCorrectParam = all (keys %config);
    my @incorrectParams = grep { $_ ne $allCorrectParam } keys %params;

    if (@incorrectParams) {
        die "called with the following incorrect config key names: @incorrectParams";
    }
}

sub setConfigKeys
{
    my %fakedConfig = @_;

    _checkConfigKeysParameters(@_);

    my @fakeSubs;
    while (my ($configKey, $fakedResult) = each %fakedConfig) {
        push @fakeSubs, ($configKey => sub { return $fakedResult });
    }

    Test::MockObject->fake_module('EBox::Config', @fakeSubs);
}

1;
