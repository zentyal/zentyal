# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2012 Zentyal S.L.
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

package EBox::Squid::Model::ApplyAllowToAllExtensions;
#
use strict;
use warnings;

use base 'EBox::Squid::Model::ApplyAllowToAllBase';

use EBox::Global;
use EBox::Gettext;


sub new
{
      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);
      bless( $self, $class );

      return $self;
}


sub elementsPrintableName
{
  my ($class) = @_;
  return __('extensions');
}


sub printableTableName
{
  my ($class) = @_;
  return __('Set policy for all extensions');
}


sub listModel
{
    my ($self) = @_;
    my $squid = $self->{gconfmodule};
    my $directory = $self->directory();
    $directory =~ m{^FilterGroup/(.*?)/};
    my $profileBaseDir = $1;

    EBox::info("listModel dir:$directory $profileBaseDir");

    if ($profileBaseDir eq 'defaultFilterGroup') {
        return $squid->model('ExtensionFilter');
    } else {
        my $modelDir = "FilterGroup/keys/$profileBaseDir/filterPolicy/FilterGroupExtensionFilter";
        my $model = $squid->model('FilterGroupExtensionFilter');
        $model->setDirectory($modelDir);
        return $model;

    }

}


1;
