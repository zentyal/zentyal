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

package EBox::RemoteServices::CGI::NoSubscription;

use base qw(EBox::CGI::ClientBase);

use EBox::Gettext;

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Server unregistered'),
                                  'template' => '/msg.mas',
                                  @_);
    
    bless($self, $class);
    return $self;
}

# this CGI is a catch-all so we can get any parameter
sub optionalParameters
{
  return ['.*'];
}

sub masonParameters
{
    my ($self) = @_;
    my $msg = __('You server is not registered. Check that you have a valid subscription');
    return [
        class => 'error',
        msg   => $msg,
   ];
}

1;
