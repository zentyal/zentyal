# Class: EBox::CaptivePortal::Composite::Composite
#
#   TODO
#

package EBox::CaptivePortal::Composite::General;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#         Constructor for composite
#
sub new
  {

      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);

      return $self;

  }

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
  {

      my $description =
        {
         components      => [
                                '/captiveportal/Settings',
                                '/captiveportal/Interfaces',
                            ],
         layout          => 'top-bottom',
         name            => 'General',
         printableName   => __('Captive portal'),
         compositeDomain => 'CaptivePortal',
#         help            => __(''),
        };

      return $description;

  }

1;
