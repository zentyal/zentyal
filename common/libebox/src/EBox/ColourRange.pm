package EBox::ColourRange;
#
use strict;
use warnings;



my @colours = (

	'000000',   #black
	'00BFFF',  # deep sky blue
	'5C4033', # dark brown
        '2F4F2F', # dark green
        'FF8C00', # dark orange
        'FF1493', # deep pink
        '9932CC', # darok orchid
	'D9D919', # bright gold  

        'C0C0C0', # silver grey
        '000080', # navy blue
        'DEB887', # burlywood
	'ADFF2F', # green yellow
        'FF2400', # orange red
        'FFB6C1', # light pink
        'DDA0DD', # plum
        'B8860B', # DarkGoldenrod      

         '856363', # green cooper

	      );

sub range
{
  my ($n) = @_;
  
  my @c;
  while ($n > @colours) {
    push @c, @colours;
    $n  = $n - @colours;
  }

  push @c, @colours[0 .. ($n -1)];

  return \@c;
}


1;
