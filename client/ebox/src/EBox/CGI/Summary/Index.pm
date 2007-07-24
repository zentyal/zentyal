# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::Summary::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Summary::Page;
use EBox::Summary::Error;
use EBox::Summary::Item;
use EBox::Summary::Module;
use Error qw(:try);


sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_, title => __('Status'));
	bless($self, $class);
	return $self;
}

sub _addErrors ($$)
{
	my $page = shift;
	my $errors = shift;

	foreach my $err (@{$errors}) {
		my $item = new EBox::Summary::Module($err->{'mod'});
		$item->add(new EBox::Summary::Error(__("Error"), $err->{txt}));
		$page->add($item);
	}
}

sub _body
{
	my $self = shift;
	$self->SUPER::_body;
	my $global = EBox::Global->getInstance(1);
	my @modNames = @{$global->modNames};
	my $page = new EBox::Summary::Page();
	my @errors;
	foreach my $name (@modNames) {
		my $mod = $global->modInstance($name);
		settextdomain($mod->domain);
		my $item;
		try {
			$item = $mod->summary;
			
		} catch EBox::Exceptions::External with {
			my $ex = shift;
			push (@errors, { 'mod' => $name, 'txt' => $ex->text });
		};

		defined($item) or next;
		$page->add($item);
	}
	_addErrors($page, \@errors);
	$page->html;
}


# for now we override ClientBase _process to avoid missing arguments errors
sub _process
{}

1;
