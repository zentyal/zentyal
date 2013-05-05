# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::DesktopServices::CGI::Index;
use base 'EBox::CGI::ClientRawBase';

use Error qw(:try);
use JSON::XS;

use EBox::Global;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub _validateReferer
{
}

# Method: _process
#
#  we dont't use actuate() bz is oriented to HTML output CGIs
#
# Overrides:
#
#   <EBox::CGI::Base::_process>
#
sub _process
{
    my ($self) = @_;
    $self->{json} = undef;

    # Parse the url
    my $url = $ENV{'script'};
    $url =~ m:^([a-zA-Z]+)/([a-zA-Z]+)/$:;
    my $module_name = $1;
    my $action_name = $2;
    if ((not $module_name) or (not $action_name)) {
        return;
    }

    # List of all desktop service providers
    my $global = EBox::Global->getInstance();
    my @modules = @{$global->modInstancesOfType('EBox::Desktop::ServiceProvider')};
    foreach my $module ( @modules ) {
        # If the module is the one we are looking for
        if ($module->name() eq $module_name) {

            # All the exposed actions of the module
            my %actions = %{$module->desktopActions()};
            foreach my $actname (keys %actions) {
                # If the action is the one we are looking for
                if ($actname eq $action_name) {
                    $self->{json} = $actions{$actname}->();
                    return;
                }
            }
        }
    }
}

sub _print
{
    my ($self) = @_;
    my $json = $self->{json};
    if (not $json) {
        $json = [];
    }
    $self->JSONReply($json);
}

1;
