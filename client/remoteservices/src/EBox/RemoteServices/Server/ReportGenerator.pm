#!/usr/bin/perl -w

# Copyright (C) 2009 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::Server::ReportGenerator
#
#      This is a WS server to receive jobs from the control center to
#      dispatch to the runner daemon which must provide results in
#      some way
#

package EBox::RemoteServices::Server::ReportGenerator;

use strict;
use warnings;

use base 'EBox::RemoteServices::Server::Base';

use EBox::Exceptions::MissingArgument;
use EBox::Config;
use EBox::Global;
use YAML::Tiny;

# Group: Public class methods

# Method: generateReport
#
#     Control panel will ask eBoxes for the information required for the
#     report.
#
# Parameters:
#
#     options - Hash with options for the report generation
#
# Returns:
#
#     '' - if the report thing is not yet supported by eBox
#     YAML - a YAML encoded string with report results
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
sub generateReport
{
    my $class = shift(@_);
    my ($optionstring) =
      @{$class->_gatherParams([ qw(options) ], @_)};

    unless (defined($optionstring)) {
        throw EBox::Exceptions::MissingArgument('options');
    }
    my $yaml = YAML::Tiny->read_string($optionstring);
    my $options = $yaml->[0];
    my $full_report = {};

    $full_report->{'range'} = $options->{'range'};

    my @mods = @{EBox::Global->modInstances()};

    # Check for support about reports in this version
    unless ( $mods[0]->can('report') ) {
        return $class->_soapResult('');
    }

    for my $mod (@mods) {
        my $name = $mod->name();
        my $report = $mod->report($options->{'range'}->{'start'},
            $options->{'range'}->{'end'}, $options->{$name});
        defined($report) or next;
        for my $rep (keys %{$report}) {
            if (not defined($report->{$rep})) {
                delete $report->{$rep};
            }
        }
        $full_report->{$name} = $report;
    }

    $yaml = YAML::Tiny->new();
    $yaml->[0] = $full_report;

    my $retValue = $yaml->write_string();
    return $class->_soapResult($retValue);
}

# Method: URI
#
# Overrides:
#
#      <EBox::RemoteServices::Server::Base>
#
sub URI {
    return 'urn:EBox/Services/Report';
}

# Group: Private class methods

1;
