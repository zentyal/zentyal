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

package EBox::CGI::Dashboard::Widget;

use strict;
use warnings;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Item;
use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_,
                                  'template' => '/dashboard/widgetcontent.mas');
	bless($self, $class);
	return $self;
}

sub requiredParameters
{
    return ['module', 'widget'];
}

sub _process
{
	my ($self) = @_;
	my $global = EBox::Global->getInstance(1);
    my $modname = $self->param('module');
    my $widgetname = $self->param('widget');
    my $sectionname = $self->param('section');
	my $module = $global->modInstance($modname);
    my $widget = $module->widget($widgetname);

    my @params = ();
    push(@params, 'widget' => $widget);
    $self->{params} = \@params;
}

1;
