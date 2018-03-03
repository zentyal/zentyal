# Copyright (C) 2005-2007 Warp Networks S.L.
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

package EBox::Loggerd;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::DBEngineFactory;
use EBox::Exceptions::Internal;

use TryCatch;
use Fcntl;
use Linux::Inotify2;
use POSIX;
use File::Basename;

use constant BUFFER_SIZE => 65536;

sub new
{
    my $class = shift;
    my $self = {};
    my %opts = @_;
    $self->{inotify} = undef;
    $self->{filehandlers} = {};
    $self->{buffers} = {};
    $self->{period} = EBox::Config::configkey('multi_insert_interval');
    bless($self, $class);
    return $self;
}

sub run
{
    my ($self) = @_;

    $self->initDaemon();
    EBox::init();

    my $global = EBox::Global->getInstance(1);
    my $log = $global->modInstance('logs');
    $self->{'loghelpers'} = $log->allEnabledLogHelpers();
    $self->{'dbengine'} = EBox::DBEngineFactory::DBEngine();

    if (EBox::Config::boolean('debug')) {
        my @logHelpers = map { ref $_ } @{ $self->{'loghelpers'} };
        EBox::debug("Loaded log helper classes: @logHelpers");
    }

    $self->_prepare();
    $self->_mainloop();
}

sub initDaemon
{
    my ($self) = @_;

    unless (POSIX::setsid) {
        EBox::error('Cannot start new session for ', $self->{'name'});
        exit 1;
    }

    foreach my $fd (0 .. 64) {
        POSIX::close($fd);
    }

    my $tmp = EBox::Config::tmp();
    open (STDIN,  "+<$tmp/stdin");
    if (EBox::Config::boolean('debug')) {
        open (STDOUT, "+>$tmp/stout");
        open (STDERR, "+>$tmp/stderr");
    }
}

# Method: _prepare
#
#       Init the necessary stuff, such as open fifos, use required classes, etc.
#
sub _prepare # (fifo)
{
    my ($self) = @_;

    $self->{inotify} = new Linux::Inotify2
        or EBox::error("Unable to create inotify object: $!");

    $self->{inotify}->blocking(0);

    my @loghelpers = @{$self->{'loghelpers'}};
    for my $obj (@loghelpers) {
        for my $file (@{$obj->logFiles()}) {
            my $FH;
            unless (exists $self->{filehandlers}->{$file}) {
                my $skip = 0;
                try {
                    my $dir = dirname($file);
                    $self->{inotify}->watch($dir, IN_CREATE | IN_DELETE);
                    $self->{inotify}->watch($file, IN_MODIFY |
                                                   IN_DELETE_SELF |
                                                   IN_MOVE_SELF);
                    sysopen($FH, $file, O_RDONLY);
                    sysseek($FH, 0, SEEK_END);
                } catch {
                    EBox::warn("Error creating inotify watch on $file: $!");
                    $skip = 1;
                }
                next if $skip;

                $self->{filehandlers}->{$file} = $FH;
                $self->{buffers}->{$file} = '';
            }

            push @{$self->{'objects'}->{$file}}, $obj;
        }
    }
}

sub _parseLog
{
    my ($self, $file) = @_;

    my $buffer;
    my $FH = $self->{filehandlers}->{$file};
    return unless defined ($FH);

    my $bytes = sysread($FH, $buffer, BUFFER_SIZE);
    return unless ($bytes);

    my $line;
    # Append the rest of the previous non-complete line
    my $rest = $self->{buffers}->{$file} . $buffer;
    while (($line, $rest) = $rest =~ m/^([^\n]+\n)?(.+)?$/s) {
        last unless ($line);
        chomp ($line);
        for my $obj (@{$self->{'objects'}->{$file}}) {
            try {
                $obj->processLine($file, $line, $self->{'dbengine'});
            } catch {
                EBox::warn("Error processing line $line of $file: $@");
            }
        }
        last unless ($rest);
    }
    $self->{buffers}->{$file} = ($rest or '');
}

sub _mainloop
{
    my ($self) = @_;

    while () {
        my @events = $self->{inotify}->read();

        foreach my $event (@events) {
            my $file = $event->fullname();

            if ($event->IN_MODIFY) {
                $self->_parseLog($file);
            } elsif ($event->IN_CREATE) {
                sysopen(my $FH, $file, O_RDONLY);
                $self->{filehandlers}->{$file} = $FH;
            } else { # IN_DELETE || IN_MOVE
                close($self->{filehandlers}->{$file});
                $self->{filehandlers}->{$file} = undef;
            }
        }

        $self->{'dbengine'}->multiInsert();
        sleep $self->{period};
    }
}

1;
