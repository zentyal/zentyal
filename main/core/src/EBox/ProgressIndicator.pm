# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::ProgressIndicator;

use EBox::Gettext;
use EBox::WebAdmin;
use EBox::Util::SHM;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;

use POSIX ":sys_wait_h";
use TryCatch;

my $KEY = 'progress_indicator';

sub create
{
    my ($class, %params) = @_;

    # check parameter correctness..
    exists $params{totalTicks} or
        throw EBox::Exceptions::MissingArgument('totalTicks named parameter not found');

    ($params{totalTicks} > 0) or
        throw EBox::Exceptions::InvalidData(
                data  => __('Total ticks'),
                value => $params{totalTicks},
                advice => __('It must be a non-zero positive number'),
        );

    exists $params{executable} or
        throw EBox::Exceptions::MissingArgument('executable named parameter not found');

    my ($executableWoArguments) = split '\s', $params{executable};
    (-x $executableWoArguments) or
        throw EBox::Exceptions::External(__x("Cannot execute {exe}", exe => $params{executable}));

    my $id = _unique_id();

    $class->_cleanupFinished();

    my $self = $class->retrieve($id);

    $self->_init($params{executable}, $params{totalTicks});

    return $self;
}

sub retrieve
{
    my ($class, $id) = @_;
    defined $id or
        throw EBox::Exceptions::MissingArgument('id');

    my $self = { id => $id };
    bless $self, $class;

    return $self;
}

sub notifyTick
{
    my ($self, $nTicks) = @_;

    defined $nTicks or
        $nTicks = 1;

    if ($nTicks <= 0) {
        throw EBox::Exceptions::InvalidData(
                data => __('Number of ticks to notify'),
                value => $nTicks,
                advice => __('must be greater than zero'),
                );
    }

    if (not $self->started()) {
        throw EBox::Exceptions::External(
                __('Executable has not been run')
                );
    }

    my $ticks = $self->_get('ticks');
    $ticks += $nTicks;

    my $totalTicks = $self->totalTicks();
    my $changedTotal = 0;
    while ($totalTicks < $ticks) {
        $totalTicks += 5;
        $changedTotal = 1;
    }

    if ($changedTotal) {
        $self->setTotalTicks($totalTicks);
    }
    $self->_set('ticks', $ticks);
}

sub ticks
{
    my ($self) = @_;

    my $data = $self->_data();
    my $ticks =  $data->{ticks};
    my $totalTicks = $data->{totalTicks};

    if ($ticks >= $totalTicks) {
        # safeguard against bad counts and zombies process
        _collectChildrens();
        return $totalTicks;
    }

    return $ticks;
}

sub setTotalTicks
{
    my ($self, $nTTicks) = @_;

    $self->_set('totalTicks', $nTTicks);
}

sub totalTicks
{
    my ($self) = @_;

    return $self->_get('totalTicks');
}

# Method: percentage
#
#     Return how many ticks have been performed of the total in
#     percentage means
#
# Returns:
#
#     String - the percentage round to two decimals
#
sub percentage
{
    my ($self) = @_;

    if ($self->finished()) {
        return 100;
    }

    my $totalTicks = $self->totalTicks();
    # Workaround to avoid illegal division by zero
    if ($totalTicks == 0) {
        return 100;
    }

    my $per = $self->ticks() / $totalTicks;
    $per = sprintf("%.2f", $per); # round to two decimals
    $per *= 100;

    return $per;
}

sub setMessage
{
    my ($self, $message) = @_;

    $self->_set('message', $message);
}

sub message
{
    my ($self) = @_;

    return $self->_get('message');
}

# Method: started
#
#     Return whether the action to perform has started or not
#
# Returns:
#
#     True  - if it has started
#     False - otherwise
#
sub started
{
    my ($self) = @_;

    return $self->_get('started');
}

# Method: finished
#
#     Return whether the action to perform has finished or not
#
# Returns:
#
#     True  - if it has finished
#     False - otherwise
#
sub finished
{
    my ($self) = @_;

    my $finished = $self->_get('finished');
    if ($finished) {
        _collectChildrens();
    }
    return $finished;
}

# Method: setAsFinished
#
#     Set the progress indicator as finished.
#
# Parameters:
#
#     retValue - Int the returned value. Possible values
#                *(Optional)* Default value: 0
#
#          - 0 : mean the progress has finished correctly
#          - >0 : mean something wrong happened
#          - otherwise: undocumented
#
#     errorMessage - String the error message
#          - if retValue == 0 this message is treated as a warning
#          - if retValue > 0 this message is treated as an error
#                    *(Optional)* Default value: ''
#
sub setAsFinished
{
    my ($self, $retValue, $errorMsg) = @_;
    defined $retValue or $retValue = 0;

    if (not $self->started()) {
        throw EBox::Exceptions::External(__('The executable has not run'));
    }

    $self->_set('finished', 1);
    $self->setRetValue($retValue);

    if (defined($errorMsg)) {
        $self->_set('errorMsg', $errorMsg);
    }

    my $ticks = $self->ticks();
    my $totalTicks = $self->totalTicks();
    if ($ticks != $totalTicks) {
        $self->_set('ticks', $totalTicks);
    }
}

# Method: retValue
#
#      Returned value if it makes sense and only if the state is
#      marked as finished
#
# Returns:
#
#      Int - the returned value, if -1 is returned, the value must not
#      take into account
#
sub retValue
{
    my ($self) = @_;

    return $self->_get('retValue');
}

# Method: setRetValue
#
#      Set returned value.
#
# Parameters:
#
#      retValue - Int the returned value, if -1 is set, the value
#      must not take into account
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if the state is not
#      finished
#
sub setRetValue
{
    my ($self, $retValue) = @_;

    unless ($self->finished()) {
        throw EBox::Exceptions::Internal('Cannot set a return value to '
                                       . 'a not finished task');
    }
    $self->_set('retValue', $retValue);
}

# Method: errorMsg
#
#      Get the error message when the executable has finished. It only
#      makes sense when <EBox::ProgressIndicator::retValue> returns a
#      value greater than zero.
#
# Returns:
#
#      String - the error message if any
#
sub errorMsg
{
    my ($self) = @_;

    return $self->_get('errorMsg');
}

sub stateAsHash
{
    my ($self) = @_;

    my $data = $self->_data();

    my $status;
    if (not $data->{started}) {
        $status = 'not running';
    } elsif ($data->{finished}) {
        my $retValue = $data->{retValue};
        if ($retValue == 0) {
            $status = 'done';
        }
        elsif ($retValue != 0 ) {
            $status = 'error';
        }
    } else {
        $status = 'running';
    }

    $data->{state} = $status;

    return $data;
}

sub id
{
    my ($self) = @_;
    return $self->{id};
}

sub destroy
{
    my ($self) = @_;

    if (exists $self->{childPid}) {
        for (0 .. 10) {
            my $kid = waitpid($self->{childPid}, WNOHANG);
            if ($kid != 0) {
                last;
            }
            sleep 1;
        }
    }

    $self->_delete();

    $_[0] = undef; # to cancel the self value
}

sub runExecutable
{
    my ($self) = @_;

    if ($self->started) {
        throw EBox::Exceptions::External(
                __('The executable has already been started')
                );
    }
    elsif ($self->finished) {
        __('The executable has already finished');
    }

    $self->_set('started', 1);

    $self->_fork();
}

sub _fork
{
    my ($self) = @_;

    my $pid = fork();
    my $id = $self->{id};

    unless (defined $pid) {
        throw EBox::Exceptions::Internal("Cannot fork().");
    }

    if ($pid) {
        $self->{childPid} = $pid;
        return; # parent returns immediately
    } else {
        EBox::WebAdmin::cleanupForExec();
        my $executable = $self->_get('executable');
        exec ("$executable --progress-id $id");
    }
}

sub _set
{
    my ($self, $key, $value) = @_;

    my $id = $self->{id};
    EBox::Util::SHM::setValue("$KEY/$id", $key, $value);
}

sub _get
{
    my ($self, $key) = @_;

    my $id = $self->{id};
    return EBox::Util::SHM::value("$KEY/$id", $key);
}

sub _data
{
    my ($self) = @_;

    my $id = $self->{id};
    return EBox::Util::SHM::hash("$KEY/$id");
}

sub _delete
{
    my ($self, $key) = @_;

    my $id = $self->{id};
    EBox::Util::SHM::deletekey("$KEY/$id");
}

sub _init
{
    my ($self, $executable, $totalTicks) = @_;

    my $id = $self->{id};
    my $data = {};

    $data->{executable} = $executable;
    $data->{totalTicks} = $totalTicks;
    $data->{ticks} = 0;
    $data->{message} = '';
    $data->{started} = 0;
    $data->{finished} = 0;
    $data->{retValue} = -1; # retValue == -1, not finished

    EBox::Util::SHM::setHash("$KEY/$id", $data);
}

sub _currentIds
{
    EBox::Util::SHM::subkeys($KEY);
}

# Method to clean up the rubbish regarding to the progress indicator
# It must be called when a new progress indicator is created, because
# a single ProgressIndicator should be alive on WebAdmin
sub _cleanupFinished
{
    my ($class) = @_;

    foreach my $id (_currentIds()) {
        try {
            my $pI = $class->retrieve($id);
            if ($pI->finished()) {
                $pI->destroy();
            }
        } catch (EBox::Exceptions::Base $e) {
            # Ignore this strange case (Already cleaned up)
            ;
        }
    }

    _collectChildrens();
}

sub _collectChildrens
{
    my $child;
    do {
        $child = waitpid(-1, WNOHANG);
    } while ($child > 0);
}

sub _unique_id
{
    my $lastId = _lastId();
    my $id;
    if ($lastId) {
        $id = $lastId + 1;
    } else {
        $id = 1;
    }

    return $id;
}

sub _lastId
{
    my @currentIds = sort _currentIds();
    if (@currentIds == 0) {
        return undef;
    }
    my $lastId = $currentIds[-1];
    return $lastId;
}

1;
