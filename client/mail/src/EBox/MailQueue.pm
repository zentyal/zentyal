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
#  	qid: Queue id.
#  	size: Message size.
#  	atime: Arrival time.
#  	sender: The sender.
#  	recipient: The recipient(s)
#  	msg: The message of error if the message couldnt be delivered.
#
# Returns:
#
#  array ref: mail queue list
#
sub mailQueueList {
	my $self = shift;

	my $temp = {};
	my @recipients;
	my @mqarray = ();
	use Data::Dumper;
	
	foreach (@{root('/usr/bin/mailq')}) {
		if ($_ =~ m/^\w.*$/) {
			my ($qid, $size, $dweek, $month, $day, $time, $sender) = $_ =~ m/^(\w+)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\d\d:\d\d:\d\d)\s+(.*)$/;
			$temp->{'qid'} = $qid;
			$temp->{'size'} = $size;
			$temp->{'atime'} = $dweek.' '.$month.' '.$day.' '.$time;
			$temp->{'sender'} = $sender;
		} elsif ($_ =~ m/^\s*\(.*$/) {
			my ($msg) = $_ =~ m/^\s*\((.*)\)$/;
			$temp->{'msg'} = $msg;
		} elsif ($_ =~ m/^\s+\w+\@.*$/) {
			my ($rec) = $_ =~ m/^\s+(\w+\@.*).*$/;
			push(@{$temp->{'recipients'}}, $rec);
		} elsif ($_ =~ m/^$/) {
			push(@mqarray, $temp);
			$temp = ();
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
	my $qid = shift;

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
sub requeueMail {
	my $qid = shift;

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
sub infoMail {
	my $qid = shift;

	my $writeon = 0;
	my @info;
	foreach (@{root("/usr/sbin/postcat -q $qid")}) {
		chomp;
		if ($writeon) { push(@info, $_);}
		if ($_ =~ m/^\*\*\* MESSAGE CONTENTS.*$/) { $writeon	= 1; }
		if ($_ =~ m/^\*\*\* HEADER EXTRACTED.*$/) { $writeon	= 0; }
	}
	pop(@info);
	
	return \@info;
}

1;
