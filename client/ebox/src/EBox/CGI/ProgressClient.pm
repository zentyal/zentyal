package EBox::CGI::ProgressClient;
#  this class is to provide helper method for any CGI which must 
#
#  See also:
#   EBox::CGI::ProgressBase
use strict;
use warnings;

sub new
{
  throw EBox::Exceptions::NotImplemented('This class must be inherited by other class which also inherits from EBox::CGI::Base');
}


# Method: showProgress
#
#    Redirect the browser to the progression screen CGI
#
#  Parameters:
#      progressIndicator - a instance of EBox::ProgressIndicator needed
#                         to drive the progress screen (mandatory)
#
#   title              - title of the page
#   currentItemCaption - caption before the actual item value 
#   itemsLeftMessage   - text after the 'x of y' 
#   endNote            - text of the note showed when the operation ends
#
#   errorNote - String text showed when operation has not finished
#               correctly
#
#   reloadInterval - reload interval in seconds (default 5)
#
#  currentItemUrl - with this you can change the CGI used to fetch the current
#                  item data. Probably you would NOT need it
#
#
#   url - URL to the progress' CGI. Most of the time you don't want to touch this
#          default: '/Progress'
#
#   (other parameters) - will be passed to the CGI if they are defined
sub showProgress
{
  my ($self, %params) =@_;
  $params{progressIndicator} or 
    throw EBox::Exceptions::MissingArgument('progressIndicator');
  $params{url} or $params{url} = '/Progress';

  my $progressIndicator = delete $params{progressIndicator};
  my $url               = delete $params{url};

  $self->cgi()->delete(@{ $self->params() });

  $self->cgi()->param('progress' => $progressIndicator->id);
  $self->keepParam('progress');

  # put the optional parameters in the CGI
  while (my ($param, $value) = each %params) {
    $self->cgi()->param($param, $value);
    $self->keepParam($param);
  }

  $self->setChain($url);
}

1;
