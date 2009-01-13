# Copyright (C) 2008 eBox Technologies S.L.
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

package EBox::CGI::Monitor::DisplayGraphs;

# Class: EBox::CGI::Monitor::DisplayGraphs
#
#     CGI to display measures graph under a tab
#

use strict;
use warnings;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Method: new
#
#       Constructor for UpdateGraph CGI
#
# Returns:
#
#       Index - The object recently created
#
sub new
{

    my $class = shift;

    my $self = $class->SUPER::new(
        template => '/monitor/graphs.mas',
        @_
       );

    $self->{domain} = 'ebox-monitor';
    bless($self, $class);

    return $self;

}

# Method: optionalParameters
#
# Overrides:
#
#     <EBox::CGI::Base::optionalParameters>
#
sub optionalParameters
{
    return [ 'period' ];
}


# Method: requiredParameters
#
# Overrides:
#
#     <EBox::CGI::Base::requiredParameters>
#
sub requiredParameters
{
    return [ ];
}


# Method: masonParameters
#
# Overrides:
#
#     <EBox::CGI::Base::masonParameters>
#
sub masonParameters
{

    my ($self) = @_;

    my $params = $self->paramsAsHash();

    unless(exists($params->{period})) {
        $params->{period} = 'lastHour';
    }

    my $mon = EBox::Global->getInstance()->modInstance('monitor');

    my $measuredData = $mon->allMeasuredData($params->{period});

    return [
        graphs => $measuredData,
        period => $params->{period},
       ];

}

1;
