# Copyright (C) 2008 eBox Technologies S.L.
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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA

package EBox::Dashboard::CounterGraph;

use strict;
use warnings;

use base 'EBox::Dashboard::Graph';
use EBox::Gettext;
use EBox;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new();
    $self->{title} = shift;
    $self->{name} = shift;
    $self->{value} = shift;
    $self->{size} = shift;
    $self->{type} = 'graph';
    if($self->{size} eq 'small') {
        $self->{width} = 175;
        $self->{height} = 100;
    } else {
        $self->{width} = 350;
        $self->{height} = 200;
    }
    bless($self, $class);
    
    $self->update();
    return $self;
}

sub update
{
    my ($self) = @_;
    my $counterdir = EBox::Config::tmp() . '/counter/';
    if(! -d $counterdir) {
        mkdir($counterdir);
    }
    my $counterfile = $counterdir . '/' . $self->{name} . '.counter';

    my $date = time();
    my $startdate = $date - 120;
    my $secs;
    my $value = 0;
    if(-f $counterfile) {
        my $olddate = (stat $counterfile)[9]; 
        if($olddate < $startdate) {
            unlink($counterfile);
        } else {
            $secs = $date - $olddate;
            open(COUNTERFILE, "< $counterfile");
            my $oldcounter = <COUNTERFILE>;
            close COUNTERFILE;
            chomp($oldcounter);
            if($secs != 0) {
                $value = ($self->{value}-$oldcounter)/$secs; 
            }
        }
    }
    use EBox;
    open(COUNTERFILE, "> $counterfile");
    print COUNTERFILE $self->{value};
    close COUNTERFILE;
    $self->{value} = $value;
}

sub HTMLViewer()
{
    return '/dashboard/graph.mas';
}

1;
