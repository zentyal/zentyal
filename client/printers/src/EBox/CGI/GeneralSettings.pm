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

package EBox::CGI::Printers::GeneralSettings;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Printers;

# Constructor: new
#
#      Constructor for the CGI
#
sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new(@_);

    $self->{domain} = 'ebox-printers';
    $self->{chain} = "Printers/ShowPrintersUI";

    bless( $self, $class);
    return $self;

}

# Method: requiredParameters
#
# Overrides:
#
#     <EBox::CGI::Base::requiredParameters>
#
sub requiredParameters
{
    my ($self) = @_;

    return [qw(enableStandaloneCups)];

}

# Method: optionalParameters
#
# Overrides:
#
#     <EBox::CGI::Base::optionalParameters>
#
sub optionalParameters
{

    my ($self) = @_;

    return [qw(change)];

}

# Method: actuate
#
# Overrides:
#
#     <EBox::CGI::Base::actuate>
#
sub actuate
{
    my ($self) = @_;

    my $enableStandaloneCups = $self->param('enableStandaloneCups');
    my $printers = EBox::Global->modInstance('printers');
    my $oldEnabled = $printers->isStandaloneCupsEnabled();
    $printers->enableStandaloneCups($enableStandaloneCups);

    if ( not $oldEnabled and $enableStandaloneCups ) {
        $self->setMsg(__('Standalone cups enabled'));
    } elsif ( $oldEnabled and not $enableStandaloneCups ) {
        $self->setMsg(__('Standalone cups disabled'));
    }

}

1;
