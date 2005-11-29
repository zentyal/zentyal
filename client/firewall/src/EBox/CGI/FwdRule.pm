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

package EBox::CGI::Firewall::FwdRule;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{domain} = 'ebox-firewall';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	my $firewall = EBox::Global->modInstance('firewall');

	$self->{redirect} = "Firewall/FwdRules";
	$self->{errorchain} = "Firewall/FwdRules";

	if (defined($self->param('add'))) {
		$self->_requireParam('action', __('action'));
		$firewall->addFwdRule($self->param("protocol"),
				      $self->param("saddr"),
				      $self->param("smask"),
				      $self->param("sportfrom"),
				      $self->param("sportto"),
				      $self->param("daddr"),
				      $self->param("dmask"),
				      $self->param("dportfrom"),
				      $self->param("dportto"),
				      $self->param("nsaddr"),
				      $self->param("nsport"),
				      $self->param("ndaddr"),
				      $self->param("ndport"),
				      $self->param("action"));
	} elsif (defined($self->param('delete'))) {
		$self->_requireParam('rulename', __('rule'));
		$firewall->removeFwdRule($self->param("rulename"));
	} elsif (defined($self->param('change'))) {
		my $active = undef;
		if ($self->param("active") eq 'yes') {
			$active = 1;
		}
		$self->_requireParam('rulename', __('rule'));
		$self->_requireParam('action', __('action'));
		$firewall->changeFwdRule($self->param("rulename"),
				      $self->param("protocol"),
				      $self->param("saddr"),
				      $self->param("smask"),
				      $self->param("sportfrom"),
				      $self->param("sportto"),
				      $self->param("daddr"),
				      $self->param("dmask"),
				      $self->param("dportfrom"),
				      $self->param("dportto"),
				      $self->param("nsaddr"),
				      $self->param("nsport"),
				      $self->param("ndaddr"),
				      $self->param("ndport"),
				      $self->param("action"),
				      $active);
	} elsif (defined($self->param('up'))) {
		$self->_requireParam('rulename', __('rule'));
		$firewall->FwdRuleUp($self->param('rulename'));
	} elsif (defined($self->param('down'))) {
		$self->_requireParam('rulename', __('rule'));
		$firewall->FwdRuleDown($self->param('rulename'));
	} elsif (defined($self->param('edit'))) {
		$self->_requireParam('rulename', __('rule'));
		$self->keepParam('rulename');
		$self->{chain} = "Firewall/FwdRuleEdit";
	}

}

1;
