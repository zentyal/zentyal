# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Dashboard::CGI::WidgetJSON;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Item;
use TryCatch;
use JSON -convert_blessed_universally;

sub new # (error=?, msg=?, cgi=?)
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
    return ['module', 'widget'];
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
    my $global = EBox::Global->getInstance(1);
    my $modname = $self->param('module');
    my $widgetname = $self->param('widget');
    my $module = $global->modInstance($modname);
    $self->{widget} = $module->widget($widgetname);
}

# Method: _print
#
# Overrides:
#
#   <EBox::CGI::Base::_print>
#
sub _print
{
    my ($self) = @_;

    my $response = $self->response();
    $response->content_type('application/json; charset=utf-8');

    local $JSON::ConvBlessed = 1;

    my $json = new JSON;
    try {
        my $js = $json->allow_blessed->convert_blessed->encode( $self->{widget} );
        $response->body($js);
    } catch {
    }
}

1;
