# Copyright (C) 2009-2014 Zentyal S.L.
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
#

use strict;
use warnings;

package EBox::AntiVirus::Model::FreshclamStatus;

use base 'EBox::Model::DataForm::ReadOnly';

no warnings 'experimental::smartmatch';
use feature 'switch';

use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;

use ClamAV::XS;
use Date::Calc;
use TryCatch::Lite;

use constant CLAMAV_LOG_FILE => '/var/log/clamav/clamav.log';
use constant FRESHCLAM_LOG_FILE => '/var/log/clamav/freshclam.log';

# Group: Protected methods

# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
#
sub _table
{
    my @tableDesc =
        (
         new EBox::Types::Text(
                               fieldName => 'message',
                               printableName => __('Status'),
                              ),
         new EBox::Types::Text(
                               fieldName => 'date',
                               printableName => __('Date'),
                              ),
         new EBox::Types::Int(
                              fieldName     => 'nSignatures',
                              printableName => __('Signatures'),
                          ),
        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Database Update Status'),
                      pageTitle          => __('Antivirus'),
                      modelDomain        => 'AntiVirus',
                      tableDescription   => \@tableDesc,

                     };

    return $dataForm;
}

# Method: _content
#
#     Provide the content to the fields
#
# Overrides:
#
#     <EBox::Model::DataForm::Readonly::_content>
#
sub _content
{
    my ($self) = @_;

    my $antivirus  = $self->{'confmodule'};
    my $state;
    try {
        $state = $antivirus->freshclamState();
    } catch (EBox::Exceptions::Internal $e) {
        $state = { date => undef };
    }

    my $date       = delete $state->{date};
    my $logDate = 0;

    my $event;
    my $eventInfo;
    my $nSig = 0;
    if (defined $date) {
        # select which event is active if an event has happened
        while (($event, $eventInfo) = each %{ $state } ) {
            if ($eventInfo) {
                last;
            }
        }
        $logDate = $self->_lastUpdateDate();
        try {
            $nSig = ClamAV::XS::signatures();
        } catch ($e) {
            EBox::error($e);
            $nSig = -1;
        }
    }
    else {
        $date  = time();
        if ( not $antivirus->configured() ) {
            $event = 'unconfigured';
        } elsif ( not $antivirus->isEnabled() ) {
            $event = 'disabled';
        } else {
            $event = 'uninitialized';
            $logDate = $self->_lastUpdateDate();
            try {
                $nSig = ClamAV::XS::signatures();
            } catch ($e) {
                EBox::error($e);
                $nSig = -1;
            }
        }
    }

    if ($nSig and ($logDate > $date)) {
        $date = $logDate;
        # adjust event to reflect the last successful update
        $event = 'update';
    }

    # build appropiate msg
    my $msg;
    given ( $event ) {
        when ('uninitialized')  {
            $msg = __(q{The antivirus database has not been updated since the module was enabled.});
        }
        when ('error')    { $msg = __('The last update failed.'); }
        when ('outdated') { $msg = __('Last update successful.'); }
        when ('update')   { $msg = __('Last update successful.'); }
        when ('unconfigured') {
            $msg = __('The antivirus module is not configured. Enable it first in Module Status section.');
        }
        when ('disabled') {
            $msg = __('The antivirus module is not enabled. Enable it first to know the antivirus status.');
        }
        default { $msg = __x('Unknown event {event}.', event => $event, ); }
    }

    my $printableDate =  _formatDate($date);
    return {
            message     => $msg,
            date        => $printableDate,
            nSignatures => $nSig,
           }
}

# Group: Private methods

sub _formatDate
{
    my ($date) = @_;
    my $localDate = localtime($date);

    return $localDate;
}

sub _commercialMsg
{
    return __sx('Want to protect your system against scams, spear phishing, frauds and other junk? Get one of the {oh}Commercial Editions{ch} that will keep your Antvirus database always up-to-date.',
                oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>');
}

# Get the last updated date from clamav log file
sub _lastUpdateDate
{
    # get last update date
    my $date = 0;
    my $cmd = q{grep  'Database updated' } . FRESHCLAM_LOG_FILE . '| tail -n 1';
    my $output = EBox::Sudo::root($cmd);
    my $line = $output->[0];
    if (defined $line) {
        my ($dateStr) = $line =~ m/^(.*?)\s+->\s+Database\s+updated/;
        if ($dateStr) {
            $date = _strToTime($dateStr);
        }
    }
    return $date;
}

sub _strToTime
{
    my ($str) = @_;
    my ($ignoredWday, $monthStr, $mday, $timeString, $year) = split '\s+', $str;
    my $month = Date::Calc::Decode_Month($monthStr);
    my ($hour, $min, $sec) = split ':', $timeString, 3;
    my $date = Date::Calc::Date_to_Time($year,$month,$mday, $hour,$min,$sec);
    defined $date or $date = 0;
    return $date;
}

1;
