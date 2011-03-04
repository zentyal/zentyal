# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::CGI::Monitor::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use  EBox::Exceptions::Command;

use Error qw(:try);

# Group: Public methods

# Method: new
#
#       Constructor for Index CGI
#
# Returns:
#
#       Index - The object recently created
#
sub new
{

    my $class = shift;

    my $self = $class->SUPER::new('title'    => __('Monitoring'),
                                  'template' => 'monitor/index.mas',
				  @_);

    $self->{domain} = 'ebox-monitor';
    bless($self, $class);

    return $self;

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

    my $mon = EBox::Global->getInstance()->modInstance('monitor');

    if ( not $mon->configured() ) {
        $self->setTemplate('/msg.mas');
        return [ msg => __x('You must enable monitor module to see monitor graphs '
                            . 'in {openhref}Module Status{closehref} section.',
                            openhref  => qq{<a href="/ebox/ServiceModule/StatusView">},
                            closehref => qq{</a>}),
                 class => 'note' ];
    }


    my $needSaveChanges = 0;

    my $measuredData;

    try {
        $measuredData = $mon->allMeasuredData();
    } catch EBox::Exceptions::Internal with {
        my $ex = shift;
        my $error = $ex->text();

        if ($error =~ m/Need to save changes/) {
            $needSaveChanges = 1;
        } else {
            $ex->throw();
        }
    };

    if ($needSaveChanges) {
            $self->setTemplate('/msg.mas');
            return [
                    msg => __x('You must save the changes in module status to see monitor graphs '
 . 'in the {openhref}Save changes{closehref} section. In case it is already enabled you must wait for a few seconds to collect the first monitor data',
                            openhref  => qq{<a href="/ebox/Finish"><em>},
                            closehref => qq{</em></a>}),
                    class => 'note' ];
        }


    return [
        URL           => '/ebox/Monitor/DisplayGraphs',
        periods       => EBox::Monitor::Configuration::TimePeriods(),
        initialGraphs => $measuredData,
        tabName       => 'timePeriods',
       ];

}

1;
