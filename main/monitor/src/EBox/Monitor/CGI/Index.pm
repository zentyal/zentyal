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

package EBox::Monitor::CGI::Index;

use base 'EBox::CGI::ClientBase';

use EBox::Exceptions::Command;
use EBox::Gettext;
use EBox::Global;
use EBox::Monitor::Configuration;

use TryCatch::Lite;

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
                            openhref  => qq{<a href="/ServiceModule/StatusView">},
                            closehref => qq{</a>}),
                 class => 'note' ];
    }

    my ($msg, $msgClass) = ("", "");

    my $measuredData;

    my $global = EBox::Global->getInstance();

    try {
        $measuredData = $mon->allMeasuredData();
    } catch (EBox::Exceptions::Internal $e) {
        my $error = $e->text();

        if ($error =~ m/Need to save changes/ and $global->unsaved()) {
            $msg = __x('You must save the changes in module status to see monitor graphs '
                       . 'in the {openhref}Save changes{closehref} section. '
                       . 'In case it is already enabled you must wait for a '
                       . 'few seconds to collect the first monitor data',
                       openhref  => qq{<a href="/Finish"><em>},
                       closehref => qq{</em></a>});
            $msgClass = 'note';
        } else {
            $msg = __x('{p}An error has happened reading RRD files: {error}.{ep}'
                       . '{p}Retry to check if it is fixed.{ep}'
                       . '{p}If not, this can be easily fixed by starting over again removing '
                       . 'the {dir} content and launching this command: {cmd}.{ep}'
                       . 'Take into account your monitor data will be lost.',
                       error => "<strong>$error</strong>", p => '<p>', ep => '</ep>',
                       dir => EBox::Monitor::Configuration::RRD_BASE_DIR,
                       cmd => 'sudo service monitor restart');
            $msgClass = 'warning';
        }
    }

    if ($msg) {
            $self->setTemplate('/msg.mas');
            return [ msg => $msg,
                     class => $msgClass ];
    }

    return [
        URL           => '/Monitor/DisplayGraphs',
        periods       => EBox::Monitor::Configuration::TimePeriods(),
        initialGraphs => $measuredData,
        tabName       => 'timePeriods',
        community     => $global->communityEdition(),
    ];
}

1;
