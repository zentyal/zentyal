# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::MailQueue;

use strict;
use warnings;

use EBox::Config;
use EBox::Sudo qw( :all );

BEGIN {
    use Exporter ();
    our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
    
    @ISA = qw(Exporter);
    @EXPORT = qw();
        %EXPORT_TAGS  = (all => [qw{
                                        mailQueueList
                                        removeMail
                                        requeueMail
                                        infoMail
                                } ],
                        );
    @EXPORT_OK = qw();
    Exporter::export_ok_tags('all');
    $VERSION = EBox::Config::version;
}

#
# Method: mailQueueList
#
#  Returns an array ref of hashes with the list mail queue. The hashes contains:
#       qid: Queue id.
#       size: Message size.
#       atime: Arrival time.
#       sender: The sender.
#       recipient: The recipient(s)
#       msg: The message of error if the message couldnt be delivered.
#
# Returns:
#
#  array ref: mail queue list
#
sub mailQueueList 
{
    my ($class) =  @_;

    my $entry = {};
    my @recipients;
    my @mqarray = ();
#    use Data::Dumper;
    
    my $mailqOutput = root('/usr/bin/mailq');
    foreach my $line (@{ $mailqOutput  }) {
        if ($line =~ m/^-/) {
            next;
        }
        elsif ($line =~ m/^\w+\s/) {
            # this is the id + info line
            my ($qid, $size, $dweek, $month, $day, $time, $sender) = 
                split '\s+', $line;
            $entry->{'qid'} = $qid;
            $entry->{'size'} = $size;
            $entry->{'atime'} = $dweek.' '.$month.' '.$day.' '.$time;
            $entry->{'sender'} = $sender;
        } elsif ($line =~ m/^\s*\(.*$/) {
            # this is amessage line
            my ($msg) = $line =~ m/^\s*\((.*)\)$/;
            $entry->{'msg'} = $msg;
        } elsif ($line =~ m/^\s+\w+\@.*$/) {
            # this a recipient line
            my ($rec) = $line =~ m/^\s+(\w+\@.*).*$/;
            push(@{$entry->{'recipients'}}, $rec);
        } elsif ($line =~ m/^$/) {
            # empty line signals the boundary between messages
            push(@mqarray, $entry);
            $entry = ();
            @recipients = [];
        }
    }
    return \@mqarray;
}

#
# Method: removeMail
#
#  This method removes a mail from queue.
#
# Parameters:
#
#  qid: queue id.
#

sub removeMail {
    my ($qid) = @_;

    root("/usr/sbin/postsuper -d $qid");
}

#
# Method: requeueMail
#
#  This method requeues a mail from queue.
#
# Parameters:
#
#  qid: queue id.
#
sub requeueMail 
{
    my ($qid) = @_;

    root("/usr/sbin/postsuper -r $qid");
}

#
# Method: infoMail
#
#  This method returns extra mail information like subject and body contents.
#
# Parameters:
#
#  qid: queue id.
#
# Returns:
#
#  string: Extra mail information
sub infoMail 
{
    my ($qid) = @_;

    my $writeon = 0;
    my @info;
    foreach (@{root("/usr/sbin/postcat -q $qid")}) {
        chomp;
        if ($writeon) { push(@info, $_);}
        if ($_ =~ m/^\*\*\* MESSAGE CONTENTS.*$/) { $writeon    = 1; }
        if ($_ =~ m/^\*\*\* HEADER EXTRACTED.*$/) { $writeon    = 0; }
    }
    pop(@info);
        
    return \@info;
}

1;
