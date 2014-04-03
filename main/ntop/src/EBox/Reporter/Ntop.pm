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

use warnings;
use strict;

package EBox::Reporter::Ntop;

use base 'EBox::Reporter::Base';

use EBox::Exceptions::Internal;
use EBox::Global;
use EBox::Ntop;
use EBox::Validate;
use List::MoreUtils;
use RRDs;
use Time::Piece;

# Class: EBox::Reporter::Ntop
#
#     Perform the network monitoring data to send. In this case the
#     data is sent in raw format as required by this application to be
#     useful.
#

# Group: Public methods

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    my $gl = EBox::Global->getInstance();
    $self->{mod} = $gl->modInstance($self->module());
    return $self;
}

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'ntop';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'ntop_traffic';
}

# Method: enabled
#
#      The reporter is only enabled if the module is enabled
#
# Overrides:
#
#      <EBox::Reporter::Base::enabled>
#
sub enabled
{
    my ($self) = @_;

    return ($self->{mod}->isEnabled());
}

# Group: Protected methods

# Read RRD files for latest modifications of BPS by app

sub _consolidate
{
    my ($self, $begin, $end) = @_;

    my $ifaces = $self->{mod}->model('Interfaces')->ifacesToMonitor();
    my $rrdDirPath = EBox::Ntop::NTOPNG_DATA_DIR;

    # Prepare RRDs params
    # Maximum resolution is required
    my $beginStr = "-s $begin";
    my $endStr   = "-e $end";

    my %retData;

    foreach my $iface (@{$ifaces}) {
        my $baseIfacePath = "$rrdDirPath/$iface/rrd";
        next unless (-d $baseIfacePath);
        opendir(my $dh, $baseIfacePath);
        while(my $name = readdir($dh)) {
            my $dirName = "$baseIfacePath/$name";
            # By now, only IPv4 addresses are supported
            next unless (EBox::Validate::checkIP($name));
            opendir(my $difaceh, $dirName);
            while (my $rrdName = readdir($difaceh)) {
                my $rrdFileName = "$dirName/$rrdName";
                next unless (-f $rrdFileName);
                my ($time, $step, $names, $data) = RRDs::fetch($rrdFileName, 'AVERAGE',
                                                               $beginStr, $endStr);
                my $err = RRDs::error;
                if ($err) {
                    throw EBox::Exceptions::Internal("Error fetching data from $rrdFileName: $err");
                }

                my ($app) = $rrdName =~ /^(.*)\.rrd$/;
                my $clientIP = $name;
                foreach my $line (@{$data}) {
                    if (defined($line->[0]) and defined($line->[1])) {
                        my $sent = $line->[0] + 0.0; # Turn into a number
                        my $rcvd = $line->[1] + 0.0;
                        if ($sent > 0 or $rcvd > 0) {
                            # Sent/Received data
                            my $date = localtime($time); # Time::Piece object
                            # is returned
                            my $dateIdx = $date->ymd('/');
                            my $minute  = $date->min();
                            my $hour    = $date->hour();
                            my @result  = map { $_ * $step } @{$line};
                            if (scalar(@{$ifaces}) > 1) {
                                my $currentData = $retData{$clientIP}->{$app}->{$dateIdx}->{$hour}->{$minute};
                                if (defined($currentData)) {
                                    @result = List::MoreUtils::pairwise { $a + $b } @{$currentData}, @result;
                                }
                            }
                            $retData{$clientIP}->{$app}->{$dateIdx}->{$hour}->{$minute} = \@result;
                        }
                    }
                    $time += $step;
                }
            }
        }
        closedir($dh);
    }

    my @retData;
    # Turn data structure from hash to array
    foreach my $clientIP (keys(%retData)) {
        foreach my $app (keys(%{$retData{$clientIP}})) {
            foreach my $dateIdx (keys(%{$retData{$clientIP}->{$app}})) {
                push(@retData, { 'metadata' => { 'ip'   => $clientIP,
                                                 'app'  => $app,
                                                 'date' => $dateIdx },
                                 'data' => $retData{$clientIP}->{$app}->{$dateIdx} });
            }
        }
    }

    return \@retData;
}

1;
