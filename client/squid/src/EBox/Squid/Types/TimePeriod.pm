package EBox::Squid::Types::TimePeriod;
use base 'EBox::Types::Abstract';

use strict;
use warnings;

use EBox::Gettext;

use Perl6::Junction qw(all);

my @days = qw(monday tuesday wednesday thursday friday saturday sunday);
use constant ALL_DAYS => 'MTWHFAS';

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
      $params{'HTMLSetter'} ='/ajax/setter/squid/timePeriod.mas';
  }
  unless (exists $params{'HTMLViewer'}) {
      $params{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
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


# Method: fields
#
#    Overrides <EBox::Types::Abstract::fields> method
#
sub fields
{
    my ($self) = @_;

    my $name = $self->fieldName();
    my @fields = (
                  $name . '_from',
                  $name . '_to',
                 );

    push @fields, map {
        $name . '_' . $_
     } @days; 


    return @fields;
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

    return $self->{'from'};
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

    return $self->{'to'};
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


sub _setMemValue
{
    my ($self, $params) = @_;

    my $name = $self->fieldName();
    my @fields = ('from', 'to', @days);

    foreach my $field (@fields) {
        my $paramName = $name . '_' . $field;
        $self->{$field} = $params->{$paramName};
    }

}


# Method: _storeInGConf
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInGConf>
#
sub _storeInGConf
{
    my ($self, $gconfmod, $key) = @_;

    my $name = $self->fieldName();

    my @stringFields = qw(from to);
    my @boolFields   = @days;


    foreach my $field (@stringFields, @boolFields) {
        my $fieldKey = "$key/" . $name . '_' . $field;
        $gconfmod->unset($fieldKey);
    }

    foreach my $field (@stringFields) {
        my $fieldKey = "$key/" . $name . '_' . $field;
        $gconfmod->set_string($fieldKey, $self->$field());
    }

    foreach my $field (@boolFields) {
        my $fieldKey = "$key/" . $name . '_' . $field;
        $gconfmod->set_bool($fieldKey, $self->$field());
    }
}

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_restoreFromHash>
#
sub _restoreFromHash
{
    my ($self, $hash) = @_;

    my $name = $self->fieldName();
    my @fields = ('from', 'to', @days);

    foreach my $field (@fields) {
        my $hashField = $name . '_' . $field;
        $self->{$field} = $hash->{$hashField};
    }


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
                   __x('Bad houro f the day format: {h}', h => $hours)
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
                   __x('Bad minutes  format: {mi}', 'mi' => $minutes)
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

#    my $name = $self->fieldName();

    return 1;
}

# Method: _setValue
#
#     Set the value defined as a string in the
#     printableValue. That is, to define a port range, you can choose
#     one of following:

# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - String as defined above
#
sub _setValue # (defaultValue)
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
    
    

    
#     use Data::Dumper;
#     print Dumper \%memValueParams;
    $self->setMemValue(\%memValueParams);

}



1;
