# Copyright (C) 2009 Warp Networks S.L.
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

package EBox::Squid::Model::FilterGroupDomainFilterSettings;
use base 'EBox::Squid::Model::DomainFilterSettingsBase';

use strict;
use warnings;

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Validate;

# Group: Public methods


sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    
    bless $self, $class;
    return $self;
}



# Method: _table
#
#
sub _table
{
    my ($self) = @_;
 

    my $dataForm = {
        tableName          => 'FilterGroupDomainFilterSettings',
        printableTableName => __('Domain filter settings'),
        modelDomain        => 'Squid',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => $self->_tableHeader(),


        messages           => {
            update => __('Filtering settings changed'),
        },
    };


    return $dataForm;
}

sub precondition
{
    my ($self) = @_;

    my $parentComposite = $self->topParentComposite();
    my $useDefault = $parentComposite->componentByName('UseDefaultDomainFilter', 1);

    return not $useDefault->useDefaultValue();
}



sub preconditionFailMsg
{
    return __('Using default profile configuration');
}


1;

