# Copyright (C) 2009 EBox Technologies S.L.
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


package EBox::RemoteServices::CSV;

use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use Text::CSV;


sub new 
{
    my ($class, @params) = @_;
    my $self = { @params };
    bless  $self, $class;

    if (not exists $self->{max}) {
        $self->{max} = 10000;
    }
    if (not exists $self->{min}) {
        $self->{min} = 0;
    }
    if (not exists $self->{file}) {
        throw EBox::Exceptions::MissingArgument('file');
    }

    my @csvParams = ();
    if (exists $self->{csvParams}) {
        @csvParams = @{ $self->{csvParams} }
    }

    $self->{csv} = Text::CSV->new(@csvParams);
    
    $self->_openFile();
    
    return $self;
}


sub _openFile
{
    my ($self) = @_;
    my $file = $self->{file};
    my $FH;
    
    open $FH, "<$file" or 
        throw EBox::Exceptions::Internal("$file: $!"); 
    $self->{fh} = $FH;
}


sub readLine
{
    my ($self) = @_;
    my $csv = $self->{csv};
    
    while (1) {
        my $row = $csv->getline( $self->{fh} );
        if ($row) {
            my @parts = @{ $row };
            if ((@parts < $self->{min}) or (@parts > $self->{max})) {
                print __x('Skipping bad formed line: {l}', 
                          l => join(',', @parts)
                         );
                print "\n";
                next;        
            }

            return \@parts;
        }

        if ($csv->eof()) {
            last;
        }

        print $csv->error_diag();
        print "\n";
    }


    close $self->{fh};
    delete $self->{fh};

    return undef;
}

sub DESTROY
{
    my ($self) = @_;
    if (exists $self->{fh}) {
        close $self->{fh};
    }
}


1;
