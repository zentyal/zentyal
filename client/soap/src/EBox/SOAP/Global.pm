# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::SOAP::Global;

use strict;
use warnings;

use vars qw(@INC);

BEGIN
  {

      @INC = qw(/etc/perl /usr/local/lib/perl/5.8.4 /usr/local/share/perl/5.8.4 /usr/lib/perl5 /usr/share/perl5 /usr/lib/perl/5.8 /usr/share/perl/5.8 /usr/local/lib/site_perl .);
      use EBox;
      use EBox::Global;
      use EBox::Config;
      use EBox::Gettext;
      use EBox::Exceptions::Internal;
      use EBox::Exceptions::External;
      use EBox::Exceptions::Base;
      use Error qw(:try);
      use SOAP::Lite;
      use Data::Dumper;

  }

# Constructor: new
#
#     Return an instance of the <EBox::Global> class
#
# Parameters:
#
#     readonly - boolean if this value is passed, it will return a
#                readonly instance *(Optional)*
#
# Returns:
#
#     <EBox::Global> instance - It will be read-only if it's required
#
sub new
  {

      my ($class, $readonly) = @_;
      my $self = {};

      $self->{global} = EBox::Global->getInstance($readonly);

      bless($self, $class);

      return $self;

  }

# Method: isReadOnly
#
sub isReadOnly
  {

      my ($self) = @_;

      return $self->{global}->isReadOnly();

  }

# Method: modNames
#
sub modNames
  {

      my ($self) = @_;

      return $self->{global}->modNames();

  }

# Method: modExists
#
# Parameters:
#
#       name -
#
sub modExists
  {
      my ($self, $name) = @_;

      return $self->{global}->modExists($name);

  }

# Method: modInstance
#
# Parameters:
#
#       name -
#
sub modInstance
  {

      my ($self, $name) = @_;

      return $self->{global}->modInstance($name);

  }

# Method: modMethod
#
#       Run a public method from an eBox module
#
# Parameters:
#
#       module - String the module to run a method
#       nameMethod - String the method's name
#       params - an array with the params
#
# Returns:
#
#       the result given by the module method
#
# Exceptions:
#
#       - the one launched by the execution of the nameMethod from the
#       module
#       <EBox::Exceptions::External> - throw if the method is
#       not public or it's not defined or the module does not exist
#
sub modMethod
  {

      my ($self, $module, $nameMethod, @params) = @_;

      unless ( $nameMethod =~ /^[A-Za-z]+$/ ) {
          # Create the External exception
          my $exception = new EBox::Exceptions::External(
                              __x('{method} is not a public method',
                                   method => $nameMethod)
                                                  );
          die SOAP::Fault->faultstring($exception->stringify())
            ->faultdetail($exception);
      }

      if ( $self->{global}->modExists($module) ) {
          my $moduleInstance = $self->{global}->modInstance($module);
          if ( $moduleInstance->can($nameMethod) ) {
              my $exc = undef;
              my $result;
              try {
                  $result = $moduleInstance->$nameMethod(@params);
              } catch EBox::Exceptions::Base with {
                  $exc = shift;
                  $exc->{type} = ref ($exc);
              };
              # An exception has been raised
              if ( defined ( $exc ) ) {
                  die SOAP::Fault->faultstring($exc->stringify())
                    ->faultdetail($exc);
              } else {
                  # Return real result
                  return $result;
              }
          } else {
              my $exception = new EBox::Exceptions::External(
                                  __x('{method} is not a defined method',
                                      method => $nameMethod)
                                                            );
              die SOAP::Fault->faultstring($exception->stringify())
                ->faultdetail($exception);
          }
      } else {
          my $exception = new EBox::Exceptions::External(
                              __x('{module} does not exist',
                                  module => $module)
                                                        );
          die SOAP::Fault->faultstring($exception->stringify())
            ->faultdetail($exception);
      }
  }

1;
