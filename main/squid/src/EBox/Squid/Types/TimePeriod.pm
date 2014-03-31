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

package EBox::Squid::Types::TimePeriod;

use base 'EBox::Types::Abstract';

use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;

use Perl6::Junction qw(all);
use Time::Piece;

my @days = qw(monday tuesday wednesday thursday friday saturday sunday);
use constant ALL_DAYS => 'MTWHFAS';

my %daysToNumbers = (M => 1, T => 2, W => 3, H => 4, F => 5, A => 6, S => 0);

my %daysToLetters = (
                     monday    => 'M',
                     tuesday   => 'T',
                     wednesday => 'W',
                     thursday  => 'H',
                     friday    => 'F',
                     saturday  => 'A',
                     sunday    => 'S',
                    );

my %daysToPrintableLetters = (
                     monday    => __('M'),
                     tuesday   => __('T'),
                     wednesday => __('W'),
                     thursday  => __('H'),
                     friday    => __('F'),
                     saturday  => __('A'),
                     sunday    => __('S'),
                    );

my %printableDays = (
                     monday    => __('Monday'),
                     tuesday   => __('Tuesday'),
                     wednesday => __('Wednesday'),
                     thursday  => __('Thursday'),
                     friday    => __('Friday'),
                     saturday  => __('Saturday'),
                     sunday    => __('Sunday'),
                    );

sub new
{
    my ($class, %params) = @_;

    unless (exists $params{'HTMLSetter'}) {
        $params{'HTMLSetter'} = '/squid/ajax/setter/timePeriod.mas';
    }
    unless (exists $params{'HTMLViewer'}) {
        $params{'HTMLViewer'} = '/ajax/viewer/textViewer.mas';
    }
    unless (exists $params{defaultValue}) {
        $params{defaultValue} = ALL_DAYS;
    }
    unless (exists $params{type}) {
        $params{type} = 'squid-timeperiod';
    }

    my $self = $class->SUPER::new(%params);

    bless $self, $class;
    return $self;
}

sub value
{
    my ($self) = @_;

    my $st = '';

    my $hourlyPeriod = $self->hourlyPeriod();
    if ($hourlyPeriod) {
        $st .= $hourlyPeriod;
    }

    my $weekDays = $self->weekDays();
    if ($weekDays) {
        $st .= ' ' if $hourlyPeriod;
        $st .= $weekDays;
    }

    return $st;
}

sub isAllTime
{
    my ($self) = @_;
    return $self->value() eq ALL_DAYS;
}

sub isAllWeek
{
    my ($self) = @_;
    return $self->weekDays() eq ALL_DAYS;
}

sub printableValue
{
    my ($self) = @_;

    my $st = '';

    my $hourlyPeriod = $self->hourlyPeriod();
    if ($hourlyPeriod) {
        $st .= $hourlyPeriod;
    }
    elsif ($self->weekDays() eq ALL_DAYS) {
        return  __('All time');
    }

    my $weekDays = $self->printableWeekDays();
    if ($weekDays) {
        $st .= ' ' if $hourlyPeriod;
        $st .= $weekDays;
    }

    return $st;
}

#  Method: compareToHash
#
#    Overrides <EBox::Types::Abstract::compareToHash> method
#
sub compareToHash
{
    my ($self, $hash) = @_;

    my $name = $self->fieldName();
    my @fields = ('from', 'to', @days);

    foreach my $field (@fields) {
        my $hashField = $name . '_' . $field;
        if ($self->$field() ne $hash->{$hashField}) {
            return 0;
        }
    }

    return 1;
}

sub weekDays
{
    my ($self) = @_;

    my $st = '';

    my $activeDays = 0;
    foreach my $day (@days) {
        if ($self->$day()) {
            $activeDays += 1;
            $st .= $daysToLetters{$day};
        }
    }

    return $st;
}

sub days
{
    return \@days;
}

sub dayToPrintableLetter
{
    my ($self, $day) = @_;
    return $daysToPrintableLetters{$day};
}

sub printableWeekDays
{
    my ($self) = @_;
    my $st = '';

    my %activeDays;
    foreach my $day (@days) {
        if ($self->$day()) {
            $activeDays{$day} = 1;
            $st .= $daysToPrintableLetters{$day};
        }
    }

    my $nActiveDays = scalar keys %activeDays;
    if ($nActiveDays == scalar @days) {
        return __('All week');
    }
    elsif ($nActiveDays == 1) {
        my ($day) = keys %activeDays;
        return $printableDays{$day};
    }
    elsif ($nActiveDays == 2) {
        if ($activeDays{saturday} and $activeDays{sunday}) {
            return __('Weekend');
        }
    }
    elsif ($nActiveDays == 5) {
        if ((not $activeDays{saturday}) and (not $activeDays{sunday}) ) {
            return __('Work days');
        }
    }

    return $st;
}

sub hourlyPeriod
{
    my ($self) = @_;
    my $from = $self->from();
    my $to   = $self->to();

    if ((not $from) and (not $to)) {
        return '';
    }

    return $from . '-' . $to;
}

# Method: cmp
#
#    Overrides <EBox::Types::Abstract::cmp> method
#
sub cmp
{
    my ($self, $other) = @_;

    if ((ref $self) ne (ref $other)) {
        return undef;
    }

    return ($self->value() cmp $other->value());
}

sub _attrs
{
    return ['from', 'to', @days];
}

# Method: from
#
#   Return the "from" hour
#
# Returns:
#
#   string - containing the hour
sub from
{
    my ($self) = @_;
    return $self->{from};
}

# Method: to
#
#   Return the "to" hour
#
# Returns:
#
#   string - containing the hour
sub to
{
    my ($self) = @_;
    return $self->{to};
}

# Method: fromAsTimePiece
#
#   Return the "from" hour as Time::Piece object
#
sub fromAsTimePiece
{
    my ($self) = @_;
    my $from = $self->from();
    $from or $from = '00:00';
    return Time::Piece->strptime($from, '%H:%M');
}

# Method: toAsTimePiece
#
#   Return the "to" hour as Time::Piece object
#
sub toAsTimePiece
{
    my ($self) = @_;
    my $to = $self->to();
    $to or $to = '23:59';
    return Time::Piece->strptime($to, '%H:%M');
}

sub monday
{
    my ($self) = @_;

    return $self->{'monday'};
}

sub tuesday
{
    my ($self) = @_;

    return $self->{'tuesday'};
}

sub wednesday
{
    my ($self) = @_;

    return $self->{'wednesday'};
}

sub thursday
{
    my ($self) = @_;

    return $self->{'thursday'};
}

sub friday
{
    my ($self) = @_;

    return $self->{'friday'};
}

sub saturday
{
    my ($self) = @_;

    return $self->{'saturday'};
}

sub sunday
{
    my ($self) = @_;

    return $self->{'sunday'};
}

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    $self->_hoursParamsAreValid($params);
    $self->_daysParamsAreValid($params);

    return 1;
}

sub _hoursParamsAreValid
{
    my ($self, $params) = @_;
    my $name = $self->fieldName();

    my $to   = $params->{$name . '_to'};
    my $from = $params->{$name . '_from'};
    if ((not $to) and not $from) {
        return
    }
    elsif (not $from) {
        throw EBox::Exceptions::MissingArgument(__('From hour..'));
    }
    elsif (not $to) {
        throw EBox::Exceptions::MissingArgument(__('to hour..'));
    }
    elsif ($to eq $from) {
        throw EBox::Exceptions::External(
             __('You must specify two diffrent hours to the range')
        );
    }

    my @hourParams = ($name . '_from', $name . '_to');
    foreach my $param (@hourParams) {
        my $value = $params->{$param};

        if (not $value =~ m/:/) {
            # no minutes specified!
            $value .= ':00';
            $params->{$param} = $value;
        }
        my ($hours, $minutes) = split ':', $value, 2;
        if ($hours =~ m/^\d+$/) {
            if (($hours < 0) or ($hours > 23)) {
                throw EBox::Exceptions::External(
                   __x('Bad hour of the day value: {h}', h => $hours)
                                                );
            }
        }
        else {
            throw EBox::Exceptions::External(
                   __x('Bad hour of the day format: {h}', h => $hours)
                                            );
        }

        if ($minutes =~ m/^\d+$/) {
            if (($minutes < 0) or ($minutes > 59)) {
                throw EBox::Exceptions::External(
                   __x('Bad minutes value: {mi}', mi => $minutes)
                                                );
            }
        }
        else {
            throw EBox::Exceptions::External(
                   __x('Bad minutes format: {mi}', 'mi' => $minutes)
                                            );
        }
    }

    # we need to fetch the value form the params bz the value could be changed
    #   to add the missing minutes field
    my ($fromHours, $fromMinutes) = split ':', $params->{$name . '_from'};
    my ($toHours, $toMinutes)     = split ':', $params->{$name . '_to'};

    if ($fromHours > $toHours) {
        throw EBox::Exceptions::External(
           __('The end of the range is greater than the begin')
                                        );
    }
    elsif ($fromHours == $toHours) {
        if ($fromMinutes > $toMinutes) {
        throw EBox::Exceptions::External(
           __('The end of the range is greater than the begin')
                                        );
        }
    }
}

sub _daysParamsAreValid
{
    my ($self, $params) = @_;
    my $name = $self->fieldName();

    my $allDaysBanned = 1;
    foreach my $day  (@days) {
        my $param = $name . '_' . $day;

        if ($params->{$param}) {
            $allDaysBanned = 0;
            next;
        }
    }

    if ($allDaysBanned) {
        throw EBox::Exceptions::External(
         __('The time period must be at least active on one day')
                                        );
    }
}

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsSet>
#
sub _paramIsSet
{
    my ($self, $params) = @_;

    return 1;
}

# Method: _setValue
#
# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - String as defined above
#
sub _setValue
{
    my ($self, $value) = @_;

    my %memValueParams;
    my $name = $self->fieldName();

    my ($hours, $days);
    if ($value =~ m/\s/) {
        ($hours, $days) = split '\s', $value;
    }
    else {
        if ($value =~ m/\-/) {
            $hours = $value;
            $days  = ALL_DAYS;
        }
        else {
            $days = $value;
        }
    }

    if ($hours) {
        my ($from, $to) = split '-', $hours;
        $memValueParams{$name . '_from'} = $from;
        $memValueParams{$name . '_to'}   = $to;
    }

    my %lettersToDays = reverse (%daysToLetters);
    my @letters = split //, $days;
    foreach my $letter (@letters) {
        my $day = delete $lettersToDays{$letter};
        $memValueParams{$name . '_' . $day} = 1;
    }

    # days not used are false
    foreach my $day (values %lettersToDays) {
        $memValueParams{$name . '_' . $day} = 0;
    }

    $self->setMemValue(\%memValueParams);
}

sub setMemValue
{
    my ($self,  $params) = @_;
    my $name = $self->fieldName();
    my @timeParams = ($name . '_from', $name . '_to');
    foreach my $name (@timeParams) {
        if (exists $params->{$name} and $params->{$name} ) {
            $params->{$name} = _normalizeTime($params->{$name});
        }
    }
    return $self->SUPER::setMemValue($params);
}

# return a has with keys the day allowed as number
# this numbers coincide with perl localtime's $wday
sub dayNumbers
{
    my ($self) = @_;

    my $numbers = {};

    my $days = $self->weekDays();
    for (my $i = 0; $i < length ($days); $i++) {
        my $day = substr ($days, $i, 1);
        $numbers->{$daysToNumbers{$day}} = 1;
    }

    return $numbers;
}

sub _normalizeTime
{
    my ($time) = @_;
    my ($hr, $mn) = split ':', $time;
    my $newTime = sprintf("%02d", $hr);
    $newTime    .= ':';
    $newTime    .= sprintf("%02d", $mn);
    return $newTime;
}

# Method: overlaps
#
#   return wether the time period overlaps with another
#
#  Parameters
#      other - other timeperiod
sub overlaps
{
    my ($self, $other) = @_;
    if ($self->isAllTime() or $other->isAllTime()) {
        return 1;
    }

    my $fromA = $self->fromAsTimePiece();
    my $toA  =  $self->toAsTimePiece() ;
    my $fromB = $other->fromAsTimePiece();
    my $toB =  $other->toAsTimePiece();
    foreach my $wday (@days) {
        if ($self->$wday() and $other->$wday()) {
            if (($fromA <= $toB) and ($fromB <= $toA)) {
                return 1;
            }
        }
    }

    return 0;
}

1;
