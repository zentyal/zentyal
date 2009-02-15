#!perl
# Class: EBox::UsersAndGroups::Types::Password;
#
#   TODO
#
package EBox::UsersAndGroups::Types::Password;
use strict;
use warnings;

use base 'EBox::Types::Password';

use EBox::Exceptions::MissingArgument;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: restoreFromHash
#
#   Overrides <EBox::Types::Boolean::restoreFromHash>
#
#   We don't need to restore anything from disk so we leave this method empty
#
sub restoreFromHash
{

}

# Method: storeInGConf
#
#   Overrides <EBox::Types::Basic::storeInGConf>
#
#   Following the same reasoning as restoreFromHash, we don't need to store
#   anything in GConf.
#
sub storeInGConf
{

}

1;

