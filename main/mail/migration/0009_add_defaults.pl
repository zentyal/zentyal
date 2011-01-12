#!/usr/bin/perl
#
# Copyright (C) 2008-2010 eBox Technologies S.L.
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

# Add default vlaues for the following fields:
#        - postmastr address
#
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;

use constant BOUNCE_ADDRESS_KEY => 'SMTPOptions/bounceReturnAddress';
use constant BOUNCE_ADDRESS_DEFAULT => 'noreply@example.com';

sub runGConf
{
    my ($self) = @_;
    my $mail = $self->{gconfmodule};
    my $bounceAddress = $mail->get_string(BOUNCE_ADDRESS_KEY);
    if (not $bounceAddress) {
        $mail->set_string(BOUNCE_ADDRESS_KEY, BOUNCE_ADDRESS_DEFAULT);
    }

}



EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 9,
        );
$migration->execute();
