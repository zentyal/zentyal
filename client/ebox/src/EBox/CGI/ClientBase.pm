# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::ClientBase;
use strict;
use warnings;

use base 'EBox::CGI::Base';
use EBox::Gettext;
use EBox::Html;

## arguments
##		title [optional]
##		error [optional]
##		msg [optional]
##		cgi   [optional]
##		template [optional]
sub new # (title=?, error=?, msg=?, cgi=?, template=?)
{
	my $class = shift;
	my %opts = @_;

	my $self = $class->SUPER::new(@_);
	my $tmp = $class;
	$tmp =~ s/^.*?::.*?::(.*?)::(.*)//;
	$self->{module} = $1;
	$self->{cginame} = $2;
	if (defined($self->{cginame})) {
		$self->{url} = $self->{module} . "/" . $self->{cginame};
	} else {
		$self->{url} = $self->{module} . "/Index";
	}

	bless($self, $class);
	return $self;
}

sub _header
{
	my $self = shift;
	print($self->cgi()->header(-charset=>'utf-8'));
	print(EBox::Html::header($self->{title}));
}

sub _top
{
	my $self = shift;
	print(EBox::Html::title());
}

sub _menu
{
	my $self = shift;
	print(EBox::Html::menu($self->{url}));
}

sub _footer
{
	my $self = shift;
	print(EBox::Html::footer($self->{module}));
}

1;
