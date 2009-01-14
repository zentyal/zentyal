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

package EBox::CGI::Dashboard::WidgetJSON;

use strict;
use warnings;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Item;
use JSON;
use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	bless($self, $class);
	return $self;
}

sub requiredParameters
{
    return ['module', 'widget'];
}

sub actuate
{
    my ($self) = @_;
    my $global = EBox::Global->getInstance(1);
    my $modname = $self->param('module');
    my $widgetname = $self->param('widget');
    my $module = $global->modInstance($modname);
    $self->{widget} = $module->widget($widgetname);
}

sub _print
{
    my ($self) = @_;
    print($self->cgi()->header(-charset=>'utf-8',-type=>'application/json'));

    local $JSON::ConvBlessed = 1;

    my $js = objToJson($self->{widget});
    print $js;
}

1;
