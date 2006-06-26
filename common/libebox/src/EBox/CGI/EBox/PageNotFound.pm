package EBox::CGI::EBox::PageNotFound;
use base 'EBox::CGI::ClientBase';
# Description: CGI for "page not found error"
use strict;
use warnings;

use  EBox::Gettext;

sub new
{
    my $class = shift;
    my $title = __("Page not found");
    my $template = '/ebox/pageNotFound.mas';
    my $self = $class->SUPER::new(title => $title, template => $template, @_);
    bless($self, $class);
     return $self;
}

# we do nothing, 
# we can not even valdiate params because this a page not found error (any parameter can be in)
sub _process
{}

1;
