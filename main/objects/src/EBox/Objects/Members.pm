# Copyright (C) 2011 EBox Technologies S.L.
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


package EBox::Objects::Members;

use strict;
use warnings;



sub new
{
    my ($class, $membersList) = @_;

    my $self =  $membersList;
    bless($self, $class);

    return $self;
}


sub addresses
{
    my ($self, %params) = @_;
    my $mask = $params{mask};

    my @ips = map {
        my $type = $_->{type};
        if ($type eq 'ipaddr') {
            if ($mask) {
                my $ipAddr = $_->{'ipaddr'};
                $ipAddr =~ s:/.*$::g;
                [ $ipAddr =>  $_->{'mask'}]
            } else {
               $_->{'ipaddr'}
           }
        } elsif ($type eq 'iprange') {
            if ($mask) {
                map {
                    [$_ => 32 ]
               }@{ $_->{addresses} }
            } else {
                map {
                    "$_/32"
                } @{  $_->{addresses} }
            }
        } else {
            ()
        }
    } @{ $self };

    return \@ips;
}

sub iptablesSrcParams
{
    my ($self) =@_;
    my @params;
    foreach my $member (@{ $self }) {
        if ($member->{type} eq 'ipaddr') {
            push @params,  ' --source ' .  $member->{ipaddr};
        } elsif ($member->{type} eq 'iprange') {
            push @params, ' -m iprange --src-range ' . $member->{begin} . '-' . $member->{end};
        }
    }

    return \@params;
}

sub iptablesDstParams
{
    my ($self) =@_;
    my @params;
    foreach my $member (@{ $self }) {
        if ($member->{type} eq 'ipaddr') {
            push @params,  ' --source ' .  $member->{ipaddr};
        } elsif ($member->{type} eq 'iprange') {
            push @params, ' -m iprange --src-range ' . $member->{begin} . '-' . $member->{end};
        }
    }

    return \@params;
}


1;
