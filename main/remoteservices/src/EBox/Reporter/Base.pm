# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Reporter::Base;

# Class: EBox::Reporter::Base
#
#      Base class to perform the consolidation and send the result to
#      the cloud
#

use EBox;
use EBox::Config;
use EBox::DBEngineFactory;
use EBox::Exceptions::NotImplemented;
use EBox::Global;
use EBox::RemoteServices::Report;
use TryCatch::Lite;
use File::Slurp;
use File::Temp;
use JSON::XS;
use Scalar::Util;
use Time::HiRes;

# Constants
use constant BASE_DIR => EBox::Config::conf() . 'remoteservices/reporter/';

# Group: Public methods

# Constructor
sub new
{
    my ($class) = @_;

    my $self = {
        db     => EBox::DBEngineFactory::DBEngine(),
        sender => new EBox::RemoteServices::Report(),
    };
    # Use only UTC for date display
    $self->{db}->setTimezone('+0:00');
    bless($self, $class);
    return $self;
}

# Method: enabled
#
#     Return if the reporter helper is enabled or not to perform
#     consolidation.
#
#     Currently it checks whether the given module <module> exists or
#     not. Override this behaviour if you need some kind of customisation
#
sub enabled
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance();
    my $mod = $self->module();
    return 0 unless ($mod);

    return ($gl->modExists($mod));
}

# Method: module
#
#      Return the module the reporter requires to work
#
# Returns:
#
#      String - the module name
#
sub module
{
    return "";
}

# Method: name
#
#      The canonical name for the reporter
#
# Returns:
#
#      String - the canonical name
#
sub name
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: timestampField
#
#      The timestamp field for the table to consolidate from
#
# Returns:
#
#      String - the timestamp field
#
sub timestampField
{
    return 'timestamp';
}

# Method: consolidate
#
#    Perform the consolidation given a range (begin, end)
#
#    The begin time is stored in name/times.json
#    The result is stored as name/rep-$time-XXX.json
#
#    Every subclass must implement <_consolidate>
#
# Returns:
#
#    Boolean - some data were consolidated
#
sub consolidate
{
    my ($self) = @_;

    my $beginTime = $self->_beginTime();
    my $endTime   = time();
    my $inTime = ($endTime - $beginTime >= $self->_granularity());
    return 0 unless ($inTime);
    try {
        # TODO: Do not store all the result in a single var
        my $result = $self->_consolidate($beginTime, $endTime);
        $self->_storeResult($result) if ($result and (@{$result} > 0));
        $self->_beginTime($endTime);
    } catch ($e) {
        EBox::error("Can't consolidate " . $self->name() . " : $e");
    }
    return 1;
}

# Method: send
#
#    Send the results stored in JSON to the endpoint
#
#    Then, remove the file
#
sub send
{
    my ($self) = @_;

    my $dir = $self->_subdir();
    my @files = <${dir}rep-*json>;
    foreach my $file ( @files ) {
        my $result = File::Slurp::read_file($file);
        try {
            $self->{sender}->report($self->name(), $result);
        } catch ($e) {
            # If it fails, there is a journal ops to finish up the
            # sending at some point
            unlink ($file);
            $e->throw();
        }
        unlink ($file);
    }
}

# Method: log
#
#    Log the data to consolidate afterwards
#
sub log
{
    my ($self) = @_;

    my $logTime = $self->_logTime();
    my $ret = [];
    if ($logTime + $self->logPeriod() < time()) {
        try {
            $ret = $self->_log();
            $self->_logTime(time());
        } catch ($e) {
            EBox::error('Cannot log ' . $self->name() . " : $e");
        }
    }
    return $ret;
}

# Method: logPeriod
#
#      Return the log period in seconds to perform the logging
#
#      Default value: 1 hour
#
# Returns:
#
#      Int - seconds among <log> operations
#
sub logPeriod
{
    return 60 * 60;
}

# Method: consolidationTime
#
# Returns:
#
#      Int - return the latest consolidation time in seconds from
#      epoch
#
sub consolidationTime
{
    my ($self) = @_;

    return undef unless (-r $self->_subdir() . 'times.json');
    return $self->_beginTime();
}

# Group: Protected methods

# Method: _consolidate
#
#      Consolidate the report data to the given range
#
#      The data must be splitted in hour frames
#
# Parameters:
#
#      begin - Int the begin time
#
#      end   - Int the end time
#
# Returns:
#
#      Array ref - the reported data for the given range splitted in
#      hour frames
#
sub _consolidate
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: _log
#
#      Perform the data logging
#
#      Override this if you want to log something
#
# Returns:
#
#      Array ref - containing the rows to insert in <name> table
#
sub _log
{
}

# Method: _hourSQLStr
#
#    Return the SQL string as a function to truncate to hour
#
# Returns:
#
#    String - the hour SQL string
#
sub _hourSQLStr
{
    my ($self) = @_;

    my $timestampField = $self->timestampField();
    return "DATE_FORMAT($timestampField,"
           . q{'%Y-%m-%d %H:00:00') AS hour};
}

# Method: _rangeSQLStr
#
#    Return the SQL string for the range in WHERE
#
# Parameters:
#
#    begin - Int the begin timestamp
#    end   - Int the end timestamp
#
# Returns:
#
#    String - the range SQL string
#
sub _rangeSQLStr
{
    my ($self, $begin, $end) = @_;

    my $timestampField = $self->timestampField();
    return "$timestampField >= FROM_UNIXTIME($begin) AND $timestampField <= FROM_UNIXTIME($end)";
}

# Method: _groupSQLStr
#
#    Return the SQL string for the GROUP BY
#
#    If you override this, make sure you override <_hourSQLStr> method
#    as well.
#
# Returns:
#
#    String - the GROUP BY SQL string
#
sub _groupSQLStr
{
    return 'hour'
}

# Method: _booleanFields
#
#      Set those fields whose result is boolean type. This is required
#      for communication purposes
#
# Returns:
#
#      Array ref - containing the boolean fields
#
sub _booleanFields
{
    return [];
}


# Method: _granularity
#
#     Determine the granularity for sending report data to Zentyal
#     Remote
#
# Returns:
#
#     Int - the maximum granularity in seconds. It defaults to *15*
#           minutes
#
sub _granularity
{
    return 15 * 60;
}


# Group: Private methods

# The reporter sub dir
# Create it if it does not exist
sub _subdir
{
    my ($self) = @_;

    my $dirPath = BASE_DIR . $self->name() . '/';
    unless ( -d $dirPath ) {
        my $success = mkdir($dirPath);
        unless ( $success ) {
            EBox::Sudo::root('chown -R ebox:ebox ' . BASE_DIR);
            mkdir($dirPath);
        }
    }
    return $dirPath;
}

# Return the begin time
# If the file does not exist, then returns last month
# If a time is given, then it will be stored in that file
sub _beginTime
{
    my ($self, $time) = @_;

    my $filePath = $self->_subdir() . 'times.json';

    if (defined($time)) {
        File::Slurp::write_file($filePath, encode_json( { begin => $time } ));
    } else {
        if ( -r $filePath ) {
            my $fileContent = decode_json(File::Slurp::read_file($filePath));
            return $fileContent->{begin};
        } else {
            return time() - 30 * 24 * 60 * 60;
        }
    }
}

# Return the last time the logging was done
# If a time is given, then it will be stored in that file
sub _logTime
{
    my ($self, $time) = @_;

    my $filePath = $self->_subdir() . 'log.time';

    if (defined($time)) {
        open(my $fh, '>', $filePath);
        print $fh $time;
        close($fh);
    } elsif (-r $filePath) {
        open(my $fh, '<', $filePath);
        my $content = <$fh>;
        chomp($content);
        close($fh);
        return $content;
    } else {
        return 0;
    }
}

# Store the result in a file encoded in JSON
sub _storeResult
{
    my ($self, $result) = @_;

    my $dirPath = $self->_subdir();
    my $time = join("", Time::HiRes::gettimeofday());
    my $tmpFile = new File::Temp(TEMPLATE => "rep-$time-XXXX", DIR => $dirPath,
                                 SUFFIX => '.json', UNLINK => 0);
    $self->_typeResult($result);
    print $tmpFile encode_json($result);
}

# Perform required modifications for properly storing of JSON
# * Ensure numbers are stored as numbers in JSON
# * Booleans are stored as bool
sub _typeResult
{
    my ($self, $result) = @_;

    my %booleanFields = map { $_ => 1 } @{$self->_booleanFields()};

    # Ensure values are stored as numbers in JSON
    foreach my $row (@{$result}) {
        foreach my $k (keys(%{$row})) {
            if ( exists($booleanFields{$k}) ) {
                $row->{$k} = $row->{$k} ? JSON::XS::true : JSON::XS::false;
            } elsif ( Scalar::Util::looks_like_number($row->{$k}) ) {
                $row->{$k} += 0
            }
        }
    }
}

1;
