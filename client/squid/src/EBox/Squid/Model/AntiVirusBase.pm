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

# 

package EBox::Squid::Model::AntiVirusBase;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Types::Boolean;

# eBox exceptions used 
use EBox::Exceptions::External;

sub new 
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}



sub _tableDescription
{
    my @tableDescription = 
        ( 

         new  EBox::Types::Boolean(
             fieldName => 'avActive',
             printableName => __('Use antivirus'),
             editable => 1,
             defaultValue => 1
             ), 


        );

    return \@tableDescription;
}


sub active
{
    my ($self) = @_;

    if (not $self->precondition()) {
        return 0;
    }

    my $row = $self->row();
    return $row->valueByName('avActive');
}

sub precondition
{
    my ($self) = @_;
    my $antivirus = EBox::Global->modInstance('antivirus');
    defined $antivirus  or
        return undef;

    return $antivirus->isEnabled();
}  


sub  preconditionFailMsg
{
    my $antivirus = EBox::Global->modInstance('antivirus');
    my $msg;

    if ($antivirus) {
        $msg = __x(
'You cannot activate antivirus filter because the antivirus module is disabled. If you want to filter virus, first {openhref}activate the module{closehref} and come back here',
openhref => qq{<a href='/ebox/ServiceModule/StatusView'>}, 
closehref => qq{</a>},
);
    } else {
        $msg = __x(
'You cannot activate antivirus filter because the antivirus module is not installed. If you want to filter virus, first install it and then {openhref}activate the module{closehref} and come back here',
openhref => qq{<a href='/ebox/ServiceModule/StatusView'>}, 
closehref => qq{</a>},
);        
    }


    return $msg;
};




1;
