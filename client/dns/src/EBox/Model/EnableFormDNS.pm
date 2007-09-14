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

# Class: EBox::DNS::Model::EnableFormDNS 
#
# This class extends <EBox::Common::EnableForm> to be used within the
# DNS module.
#
# We extend it and change its name properly

package EBox::DNS::Model::EnableFormDNS;

use base 'EBox::Common::Model::EnableForm';

use EBox::Gettext;

use strict;
use warnings;

# eBox uses

# Group: Public methods

# Constructor: new
#
#      Create an enabled form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
sub new
{

    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless( $self, $class );

    return $self;

}

# Method: _table
#
# 	Overrides <EBox::Common::EnableForm::_table to change its name
# 	
sub _table
{

    my ($self) = @_;

    my $dataForm = $self->SUPER::_table();
    $dataForm->{'tableName'} = 'EnableFormDNS';

    return $dataForm;
}

# Method: formSubmitted
#
# Overrides:
#
#     <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{

    my ($self, $oldRow) = @_;

    my $dns = EBox::Global->modInstance('dns');
    if ( $self->enabledValue() ) {
        $self->setMessage(__('Service enabled'));
    } else {
        $self->setMessage(__('Service disabled'));
    }
    
    $dns->configureFirewall();

}

1;
