# Copyright (C) 2008 eBox Technologies S.L.
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

package EBox::CGI::Dashboard::Toggle;

use strict;
use warnings;

use base 'EBox::CGI::ClientRawBase';

use EBox;
use EBox::Gettext;
use EBox::Global;

sub new 
{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	return $self;
}

# Method: requiredParameters
#
# Overrides:
#
#   <EBox::CGI::Base::requiredParameters>
#
sub requiredParameters
{
    return [ 'element' ];
}

# Method: actuate
#
# Overrides:
#
#   <EBox::CGI::Base::actuate>
#
sub actuate
{
    my ($self) = @_;
    my $global = EBox::Global->getInstance();
    my $sysinfo = $global->modInstance('sysinfo');
    my $element = $self->unsafeParam("element");
    $sysinfo->toggleElement($element);
}

1;
