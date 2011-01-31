# Copyright (C) 2008-2011 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
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

package EBox::MailLogHelper;
use base qw(EBox::LogHelper);

use EBox::Gettext;
use EBox::Global;

use constant MAILOG => "/var/log/mail.log";
use constant TABLENAME => "mail_message";

# Table structure:
# CREATE TABLE message (
#        timestamp TIMESTAMP NOT NULL,
#        message_id VARCHAR(340),
#        client_host_ip INET NOT NULL,
#        client_host_name VARCHAR(255) NULL,
#        from_address VARCHAR(320),
#        to_address VARCHAR(320) NOT NULL,
#        message_size BIGINT,
#        relay VARCHAR(320),
#        message_type VARCHAR(10) NOT NULL,
#        status VARCHAR(25) NOT NULL,
#        message TEXT NOT NULL
#);

my %temp;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Method: domain
#
#       Must return the text domain which the package belongs to
#
sub domain
{
    return 'ebox-mail';
}

sub logFiles {
    return [MAILOG];
}

# Method: _getDate
#
#  This method returns the date and time on database format.
#
# Returns:
#
#               string - yyyy-mm-dd hh:mm:ss format.
sub _getDate
{
    my ($self, $line) = @_;

    my @date = localtime(time);

    my $year = $date[5] + 1900;
    my ($month, $day, $hour, $min, $sec) = $line =~ m/^(...) +(\d+) (..):(..):(..).*$/;

    return "$year-$month-$day $hour:$min:$sec";
}

# I need go deeper in postfix logs to get this stuff work better
sub processLine
{
    my ($self, $file, $line, $dbengine) = @_;


    if (not $line =~ m/(?:postfix)|(?:deliver)/) {
        return;
    }

    if ($line =~ m/NOQUEUE/) {
        # no admited to the queue, inserte error event
        my ($who, $hostname, $clientip, $msg, $line2) = $line =~ m/.*NOQUEUE: reject: (.*) from (.*)\[(.*)\]: (.*); (.*)$/;
        my ($from, $to) = $line2 =~ m/.*from=<(.*)> to=<(.*)> .*/;

        my $event = 'other';
        if ($msg =~ m/.*550.*$/) {
            $event = 'noaccount';
        } elsif ($msg =~ m/.*554.*$/) {
            $event = 'norelay';
        } elsif ($msg =~ m/.*552.*$/) {
            $event = 'maxmsgsize'; # XXX dont know if this case either continues
                                   # to work nor if it has worked somewhere in
                                   # the time
        } elsif ($msg =~ m/Greylisted/) {
            $event = 'greylist';
        }

        my $values = {
                      timestamp => $self->_getDate($line),
                      client_host_ip => $clientip,
                      client_host_name => $hostname,
                      from_address => $from,
                      to_address => $to,
                      status => 'reject',
                      message => $msg,
                      event => $event,
                     };

        $self->_insert($dbengine, $values);


    } elsif ($line =~ m/SASL PLAIN authentication failed/) {
        # auth failed, not admited at queue. Insert noauth event
        my ($hostname, $clientip) = $line =~ m/.*postfix\/.*: warning: (.*)\[(.*)\]: .*$/;

        my $values = {
                      timestamp => $self->_getDate($line),
                      client_host_ip => $clientip,
                      client_host_name => $hostname,
                      event => 'noauth',
                     };

        $self->_insert($dbengine, $values);

    } elsif ($line =~ m/cleanup.*message-id=/) {
        # cleanup: removed for the queue and mail gets a message id
        my ($qid, $msg_id) = $line =~ m/.*: ([0-9A-F]+): message\-id=<(.*)>.*$/;
        exists $temp{$qid} or
            return;

        $temp{$qid}{'msgid'} = $msg_id;
    } elsif ($line =~ m/deliver\((.*?)\): msgid=<(.*?)>: rejected: Quota exceeded \((.*?)\)/) {
        # quota exceeded, insert maxusrsize event
        my $to    = $1;
        my $msgid = $2;
        my $msg = $3; # XXX thois not works!
        my $qid = _qidFromMessageId($msgid);
        defined $qid or
            return;
        exists $temp{$qid} or
            return;

        $temp{$qid}{'to'}    = $to;
        $temp{$qid}{'event'} = 'maxusrsize';
        $temp{$qid}{'status'} = 'rejected';
        $temp{$qid}{'message'} = $msg;
        $temp{$qid}{'date'} = $self->_getDate($line);
        $temp{$qid}{'relay'} = 'dovecot';

        $self->_insertEvent($qid, $dbengine);
    } elsif ($line =~ m/warning: (.*?): queue file size limit exceeded/) {
        # message max size exceeded, insert maxmsgsize event
        my $qid = $1;

        $temp{$qid}{'event'} = 'maxmsgsize';
        $temp{$qid}{'status'} = 'rejected';
        $temp{$qid}{'date'} = $self->_getDate($line);

        $self->_insertEvent($qid, $dbengine);

    } elsif ($line =~ m/client=/) {
        # this is the point of entry for messages, we could only get a new qid
        # here

        my ($qid, $hostname, $clientip) = ($line =~ m/.*postfix\/.*: ([0-9A-F]+): client=(.*)\[(.*)\]/);

        $temp{$qid}{'qid'}      = $qid;
        $temp{$qid}{'hostname'} = $hostname;
        $temp{$qid}{'clientip'} = $clientip;
        $temp{$qid}{'date'} = $self->_getDate($line);

    } elsif ($line =~ m/qmgr.*from=</) {
        # get size
        my ($qid, $from, $size) = $line =~ m/.*: ([0-9A-F]+): from=<(.*)>, size=([0-9]+),.*$/;
        exists $temp{$qid} or
            return;

        $temp{$qid}{'from'} = $from;
        $temp{$qid}{'size'} = $size;
    } elsif ($line =~ m/.*: ([0-9A-F]+): to=<(.*?)>(, orig_to=<.*?>)?, relay=(.*?), .*, status=(.*?) \((.*)\)$/) {
        # to, relay, date, msg and status
        my ($qid, $to, $origTo, $relay, $status, $msg) =
                                     ($1, $2, $3, $4, $5, $6);
        exists $temp{$qid} or
            return;

        if (not $origTo) {
            $temp{$qid}{'to'} = $to;
        } else {
            $origTo =~ m/<(.*)>/;
            $temp{$qid}{'to'} = $1;
        }


        $temp{$qid}{'relay'} = $relay;
        $temp{$qid}{'status'} = $status;
        $temp{$qid}{'msg'} = $msg;
        $temp{$qid}{'date'} = $self->_getDate($line); # XXX remove

        if ($status ne 'sent') {
            if ($msg =~ m/Connection timed out/) {
                $temp{$qid}{'event'} = 'nohost';
            }
            elsif ($msg =~ /host.*said.*Relay access denied/) {
                $temp{$qid}{'event'} = 'nosmarthostrelay';
            }
            elsif ($msg =~ /server.*said.*authentication failure/) {
                $temp{$qid}{'event'} = 'nosmarthostrelay';
            }
            elsif ($msg =~ /Greylisted/) {
                $temp{$qid}{'event'} = 'greylist';
            }
            else {
                $temp{$qid}{'event'} = 'other';
            }

        }

        if (exists $temp{$qid}{'event'}) {
            $self->_insertEvent($qid,  $dbengine);
        }

    } elsif ($line =~ m/.*removed.*/) {
        # removed, last time we see the message insert event if it was not done before
        my ($qid) = $line =~ m/.*qmgr.*: (.*): removed/;
        exists $temp{$qid} or
            return;

        $temp{$qid}{'event'} = 'msgsent';
        $self->_insertEvent($qid, $dbengine);
    }

}

sub _qidFromMessageId
{
    my ($msgId) = @_;
    foreach my $mail (values %temp) {
        exists $mail->{'msgid'} or
            next;
        if ($mail->{'msgid'} eq $msgId) {
            return $mail->{'qid'};
        }
    }

    return undef;
}

sub _insertEvent
{
    my ($self, $qid, $dbengine) = @_;



    my $values = {
                  timestamp => $temp{$qid}{'date'},
                  message_id => $temp{$qid}{'msgid'},
                  client_host_ip => $temp{$qid}{'clientip'},
                  client_host_name => $temp{$qid}{'hostname'},
                  from_address => $temp{$qid}{'from'},
                  to_address => $temp{$qid}{'to'},
                  message_size => $temp{$qid}{'size'},
                  relay => $temp{$qid}{'relay'},
                  status => $temp{$qid}{'status'},
                  message => $temp{$qid}{'msg'},
                  event => $temp{$qid}{'event'},
                 };

    delete $temp{$qid};

    $self->_insert($dbengine, $values);
}


sub _insert
{
    my ($self, $dbengine, $values) = @_;

    my $mail = EBox::Global->modInstance('mail');
    my %vdomains = map { $_ => 1 } $mail->{vdomains}->vdomains();

    my $type;
    if (defined($values->{'from_address'}) and
            defined($values->{'to_address'})) {
        my $from = $values->{'from_address'};
        my $to = $values->{'to_address'};
        my($from_user, $from_domain) = split('@', $from);
        my($to_user, $to_domain) = split('@', $to);
        if(exists $vdomains{$from_domain} and
                exists $vdomains{$to_domain}) {
            $type = 'internal';
        } elsif (exists $vdomains{$from_domain}) {
            $type = 'sent';
        } elsif (exists $vdomains{$to_domain}) {
            $type = 'received';
        } else {
            $type = 'relay';
        }
    } else {
        $type = 'unknown';
    }
    $values->{'message_type'} = $type;
    $dbengine->insert(TABLENAME, $values);
}

1;
