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

package EBox::Dashboard::CGI::Section;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Item;
use TryCatch;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_,
               'template' => '/dashboard/sectioncontent.mas');
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
    return ['module', 'widget', 'section'];
}

# Method: masonParameters
#
# Overrides:
#
#   <EBox::CGI::Base::masonParameters>
#
sub masonParameters
{
    my ($self) = @_;
    my $global = EBox::Global->getInstance(1);
    my $modname = $self->param('module');
    my $widgetname = $self->param('widget');
    my $sectionname = $self->unsafeParam('section');
    my $module = $global->modInstance($modname);
    my $widget = $module->widget($widgetname);
    my $sect;
    foreach my $section (@{$widget->sections()}) {
        if ($section->{name} eq $sectionname) {
            $sect = $section;
            last;
        }
    }

    my @params = ();
    my $namespace = $modname . ":" . $widgetname;
    push(@params, 'section' => $sect);
    push(@params, 'namespace' => $namespace);
    return \@params;
}

1;
