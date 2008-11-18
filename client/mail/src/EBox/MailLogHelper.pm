# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::MailLogHelper;

use strict;
use warnings;

use EBox::Gettext;

use base qw(EBox::LogHelper);

use constant MAILOG => "/var/log/mail.log";
use constant TABLENAME => "message";

# Table structure:
# CREATE TABLE message (
#        message_id VARCHAR(340),
#        client_host_ip INET NOT NULL,
#        client_host_name VARCHAR(255) NULL,
#        from_address VARCHAR(320),
#        to_address VARCHAR(320) NOT NULL,
#        message_size BIGINT,
#        relay VARCHAR(320),
#        status VARCHAR(25) NOT NULL,
#        message TEXT NOT NULL,
#        postfix_date TIMESTAMP NOT NULL
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

    if (not $line =~ m/postfix/) {
        return;
    }

    if ($line =~ m/NOQUEUE/) {
        my ($who, $hostname, $clientip, $msg, $line2) = $line =~ m/.*NOQUEUE: reject: (.*) from (.*)\[(.*)\]: (.*); (.*)$/;
        my ($from, $to) = $line2 =~ m/.*from=<(.*)> to=<(.*)> .*/;
        
        my $event = 'other';
        if ($msg =~ m/.*550.*$/) {
            $event = 'noaccount';
        } elsif ($msg =~ m/.*554.*$/) {
            $event = 'norelay';
        } elsif ($msg =~ m/.*552.*$/) {
            $event = 'maxmsgsize';
        }
        
 

        my $values = {
                      client_host_ip => $clientip,
                      client_host_name => $hostname,
                      from_address => $from,
                      to_address => $to,
                      status => 'reject',
                      message => $msg,
                      postfix_date => $self->_getDate($line),
                      event => $event,
                     };

        $dbengine->insert(TABLENAME, $values);
                
    } elsif ($line =~ m/SASL PLAIN authentication failed/) {
        my ($hostname, $clientip) = $line =~ m/.*postfix\/.*: warning: (.*)\[(.*)\]: .*$/;
                        
        my $values = {
                      client_host_ip => $clientip,
                      client_host_name => $hostname,
                      postfix_date => $self->_getDate($line),
                      event => 'noauth',
                     };

        $dbengine->insert(TABLENAME, $values);
    } elsif ($line =~ m/client=/) {
        my ($qid, $hostname, $clientip) = ($line =~ m/.*postfix\/.*: (.*): client=(.*)\[(.*)\]/);
        
  
        $temp{$qid}{'hostname'} = $hostname;
        $temp{$qid}{'clientip'} = $clientip;
    } elsif ($line =~ m/cleanup.*message-id=/) {
        my ($qid, $msg_id1) = $line =~ m/.*: (.*): message\-id=<(.*)>.*$/;
        $temp{$qid}{'msgid'} = $msg_id1;
    } elsif ($line =~ m/qmgr.*from=</) {
        my ($qid, $from, $size) = $line =~ m/.*: (.*): from=<(.*)>, size=(.*),.*$/;
        $temp{$qid}{'from'} = $from;
        $temp{$qid}{'size'} = $size;
    } elsif ($line =~ m/.*: (.*): to=<(.*)>, relay=(.*), .*, status=(.*) \((.*)\)$/) {
        my ($qid, $to, $relay, $status, $msg) = ($1, $2, $3, $4, $5);

        $temp{$qid}{'to'} = $to;
        $temp{$qid}{'relay'} = $relay;
        $temp{$qid}{'status'} = $status;
        $temp{$qid}{'msg'} = $msg;
        $temp{$qid}{'date'} = $self->_getDate($line);

        if ($status eq 'deferred') {
            $temp{$qid}{'event'} = 'nohost';
            $self->_insertEvent($qid,  $dbengine);
        }

    } elsif ($line =~ m/.*removed.*/) {
        my ($qid) = $line =~ m/.*qmgr.*: (.*): removed/;
                
        my $event = 'msgsent';
        if ($temp{$qid}{'msg'} =~ m/.*maildir has overdrawn his diskspace quota.*/) {
            $event = 'maxusrsize';
        }

        $temp{$qid}{'event'} = $event;

        $self->_insertEvent($qid, $dbengine);
    }

}

sub _insertEvent
{
    my ($self, $qid, $dbengine) = @_;

    my $values = {
                  message_id => $temp{$qid}{'msgid'},
                  client_host_ip => $temp{$qid}{'clientip'},
                  client_host_name => $temp{$qid}{'hostname'},
                  from_address => $temp{$qid}{'from'},
                  to_address => $temp{$qid}{'to'},
                  message_size => $temp{$qid}{'size'},
                  relay => $temp{$qid}{'relay'},
                  status => $temp{$qid}{'status'},
                  message => $temp{$qid}{'msg'},
                  postfix_date => $temp{$qid}{'date'},
                  event => $temp{$qid}{'event'},
                 };


    $dbengine->insert(TABLENAME, $values);

    delete $temp{$qid};
}



1;
