package EBox::Mail::FilterProvider;
# all eBox modules which provide a mail filter must subclass this package
use strict;
use warnings;



# Method: mailFilter
#
#  return thes filter name and specifications. The specifications are a
#  reference to a hash with the following fields: 
#    - active
#    - prettyName 
#    - address
#    - port
#    - forwardPort
#    - instance 
#    - module
#
#   if there is no filter available undef will be returned instead
#
# Returns: 
#        - (name, specifications) of the available filter
#        - undef if there is not filter  avaialbe
#
# Warning: remember that the 'custom' name is reserved for user's custom
#   settings, so don't use it
sub mailFilter
{
  return undef;
}


# Method: mailFilterDashboard
#
#  add the custom dashboard values for the filter
#
#  Params:
#    - section
#
#  Returns:
#      - the given dashboard section
#
#  Default implementation:
#    doesn't add nothing to the dashboard section
sub mailFilterDashboard
{
  my ($self, $section) = @_;
  return $section;
}

# Method: mailFilterName
#
#  return the internal mail filter name
#

sub mailFilterName
{
  throw EBox::Exceptions::NotImplemented();
}

#  Method: mailMenuItem
#
#  reimplement this method if the filter needs to add a menu item to mail's menu
#
#  Returns:
#     undef if no menu item must be added or the EBox::Menu:Item to be added
sub mailMenuItem
{
  return undef;
}

1;
