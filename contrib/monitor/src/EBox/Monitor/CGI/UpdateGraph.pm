# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Monitor::CGI::UpdateGraph;

use base 'EBox::CGI::ClientRawBase';
# Class: EBox::Monitor::CGI::UpdateGraph
#
#     CGI to update a measure graph
#

use EBox::Gettext;
use EBox::Global;
use EBox::Monitor::Configuration;

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
        template => '/graph.mas',
        @_
       );

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
    return [ 'instance', 'typeInstance' ];
}

# Method: requiredParameters
#
# Overrides:
#
#     <EBox::CGI::Base::requiredParameters>
#
sub requiredParameters
{
    return [ 'measure', 'period' ];
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

    my $measure = $params->{'measure'};
    my $instance = $params->{'instance'};
    $instance = undef if (defined($instance) and $instance eq "");
    my $typeInstance = $params->{'typeInstance'};
    $typeInstance = undef if (defined($typeInstance) and $typeInstance eq "");

    my $mon = EBox::Global->getInstance()->modInstance('monitor');

    my ($periodData) = grep { $_->{name} eq $params->{period} } @{EBox::Monitor::Configuration::TimePeriods()};

    my $measuredData = $mon->measuredData(measureName  => $measure,
                                          period       => $params->{period},
                                          instance     => $instance,
                                          typeInstance => $typeInstance);

    return [ id         => $measuredData->{id},
             type       => $measuredData->{type},
             series     => $measuredData->{series},
             timetype   => $periodData->{timeType},
             repainting => 1,
            ];

}

# Group: Protected methods

# Method: _header
#
#     Dumps our own header to set javascript MIME type
#
# Overrides:
#
#     <EBox::CGI::Base::_header>
#
sub _header
{
    my ($self) = @_;

    my $response = $self->response();
    $response->content_type('application/javascript; charset=utf-8');

    return '';
}

1;
