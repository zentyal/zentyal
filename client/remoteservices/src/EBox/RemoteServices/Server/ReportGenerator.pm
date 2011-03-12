#!/usr/bin/perl -w

# Copyright (C) 2009-2011 eBox Technologies S.L.
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
#     Control panel will ask Zentyal servers for the information required
#     for the report.
#
# Parameters:
#
#     options - Hash with options for the report generation
#
# Returns:
#
#     '' - if the report thing is not yet supported by Zentyal
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
    for my $mod (@mods) {
        if (not $mod->can('report')) {
            next;
        }

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

    if (keys %{$full_report} == 0) {
        # no report support in any of the installed modules
        return $class->_soapResult('');
    }

    $yaml = YAML::Tiny->new();
    $yaml->[0] = $full_report;

    my $retValue = $yaml->write_string();

    $class->_setReportAsGenerated();

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

# Set the report data as generated to inform the user
sub _setReportAsGenerated
{
    my $rs = EBox::Global->modInstance('remoteservices');
    $rs->st_set_int('subscription/report_generated_at', time());

}

1;
