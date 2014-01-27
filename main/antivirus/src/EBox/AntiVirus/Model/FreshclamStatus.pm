# Copyright (C) 2009-2013 Zentyal S.L.
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

use feature 'switch';

use EBox::Config;
use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;
use Date::Calc;

use constant CLAMAV_LOG_FILE => '/var/log/clamav/clamav.log';
use constant FRESHCLAM_LOG_FILE => '/var/log/clamav/freshclam.log';

sub new
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: viewCustomizer
#
#      To display a permanent message
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = $self->SUPER::viewCustomizer();

    my $securityUpdatesAddOn = 0;
    if ( EBox::Global->modExists('remoteservices') ) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $securityUpdatesAddOn = $rs->securityUpdatesAddOn();
    }

    unless ( $securityUpdatesAddOn ) {
        $customizer->setPermanentMessage($self->_commercialMsg(), 'ad');
    }

    return $customizer;

}

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
    my $state      = $antivirus->freshclamState();

    my $date       = delete $state->{date};
    my $logDate = 0;

    my $event;
    my $eventInfo;
    my $nSig = 0;
    if (defined $date) {
        # select which event is active if a event has happened
        while (($event, $eventInfo) = each %{ $state } ) {
            if ($eventInfo) {
                last;
            }
        }
        ($nSig, $logDate) = $self->_nSigsAndLastDate();
    }
    else {
        $date  = time();
        if ( not $antivirus->configured() ) {
            $event = 'unconfigured';
        } elsif ( not $antivirus->isEnabled() ) {
            $event = 'disabled';
        } else {
            $event = 'uninitialized';
            ($nSig, $logDate)  = $self->_nSigsAndLastDate();
        }
    }

    if ($nSig and ($logDate > $date)) {
        $date = $logDate;
        # adjust  event to reflect the last succesful update
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

# Get the number of signatures from clamav log file
sub _nSigsAndLastDate
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

    # get n signatures
    my $nSig = undef;
    my $lastClamavDate;
    my @loadRegexes = ('Loaded.*signatures', 'reloaded.*signatures');
    foreach my $regex (@loadRegexes) {
        $cmd = "grep $regex " . CLAMAV_LOG_FILE . ' | tail -n 1';
        $output = EBox::Sudo::root($cmd);

        $line = $output->[0];
        if (defined $line) {
            my ($lineDateStr, $lineSigs) = $line =~ m/^(.*?)\s\->.*?([0-9]+)\ssignatures/;
            EBox::debug("$line -> \nlienDateStr $lineDateStr lineSigs:$lineSigs:");
            my $lineDate = _strToTime($lineDateStr);
            EBox::debug("lineDate: $lineDate");
            if ($lineDate < $date) {
                # before last update!
                next;
            }
            if ((not $lastClamavDate) or ($lastClamavDate < $lineDate)) {
                $lastClamavDate = $lineDate;
                $nSig = $lineSigs;
            }
        }
    }

    defined $nSig or
        $nSig = 0;
    return ($nSig, $date);
}

sub _strToTime
{
    my ($str) = @_;
    my ($ignoredWday, $monthStr, $mday, $timeString, $year) = split '\s+', $str;
    my $month = Date::Calc::Decode_Month($monthStr);
    my ($hour, $min, $sec)= split ':', $timeString, 3;
    my $date = Date::Calc::Date_to_Time($year,$month,$mday, $hour,$min,$sec);
    defined $date or $date = 0;
    return $date;
}

1;

