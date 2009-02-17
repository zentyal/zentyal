# Copyright (C) 2007 Warp Networks S.L.
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

#   Class: EBox::Types::HasMany
#
#       This class represents a pseudo-type to express relations amongst models.
#       When used in a model, it basically tells you that this field is
#       referencing another model which has more than one entry.
#
#       For example, let's say we have a model which represents a table 
#       of internet domains. Each domain is composed of several hosts.
#       The relation between the domain and the hosts can be expressed
#       by means of this type.
#
#
#	TODO 
#
#		- Review which methods are necessary and document them
#		- Implement backview correctly to allow the user to go back
#		  when he is done with the spawned table
#		
package EBox::Types::HasMany;

use strict;
use warnings;

use base 'EBox::Types::Abstract';

# eBox uses
use EBox::Model::ModelManager;
use EBox::Model::CompositeManager;

# Core modules
use Error qw(:try);

# Group: Public methods

sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} = undef;
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/hasManyViewer.mas';
    }
    
    $opts{'type'} = 'hasMany';
    $opts{'unique'} = undef;
    $opts{'editable'} = undef;
    $opts{'optional'} = 1;

    my $self = $class->SUPER::new(%opts);
       
    bless($self, $class);
    return $self;
}

sub printableValue
{
    my ($self) = @_;

    return undef;
}

sub value
{
    my ($self) = @_;

    return '' unless (exists $self->{'foreignModel'});
    return { 'model' => $self->{'foreignModel'}, , 
             'directory' => $self->directory() };

}

# Method: foreignModelIsComposite
#
# Returns:
#
#      bool - wether the foreign model is compostie or not
#
sub foreignModelIsComposite
{
    my ($self) = @_;
    return $self->{'foreignModelIsComposite'};
}

# Method: foreignModel
#
#      Get the foreign model which the hasMany type retrieves its
#      values
#
# Returns:
#
#      String - the foreign model, empty if there is none
#
sub foreignModel
{
    my ($self) = @_;

    return '' unless (exists $self->{'foreignModel'});
    return $self->{'foreignModel'};
}


# Method: foreignModelInstance
#
#      Get the foreign model instance used in the HasMany instance
#
# Returns:
#
#       - the foreign model instance or undef if thre is none
#
sub foreignModelInstance
{
    my ($self) = @_;

    my $value = $self->value();
    if (not $value) {
        return undef;
    }

    my $modelName = $value->{model};
    my $directory = $value->{directory};

    # directory maybe undef if the HasMany is not yet created
    $directory or
        return undef;

    my $model;
    if ($self->foreignModelIsComposite()) {
        $model = EBox::Model::CompositeManager->Instance()->composite($modelName);                
    } else {
        $model = EBox::Model::ModelManager->instance()->model($modelName);        
    }


    $model->setDirectory($directory);

    return $model;
}

# Method: setDirectory
#
#   Set the directory for the foreign model
#
# Parameters:
#
#   (POSITIONAL)
#   directory - string containing the directory
sub setDirectory
{
    my ($self, $directory) = @_;
    
    $self->{'directory'} = $directory;
}

# Method: directory
#
#   Return the directory for the foreing model if any
#
# Returns:
#
#   stirng - directory or undef if there isn't any 
sub directory
{
    my ($self) = @_;
    my $row = $self->row();

    if (not $row) {
        return undef;
    }

    my $directory = $row->dir() . '/' . $row->id();
    $directory .= '/' . $self->fieldName();

    return $directory;
}

# Method: view 
#
#   Return the view for the foreing model
#
# Returns:
#
#   string - view's url 
sub view 
{
    my ($self) = @_;
    
   if (exists $self->{'view'}) {
        return $self->{'view'};
   } else {
        return undef;
   }
}

# Method: backView 
#
#   Return the back view for the foreing model
#
# Returns:
#
#   stirng - view's url 
sub backView 
{
    my ($self) = @_;
    
   if (exists $self->{'backView'}) {
        return $self->{'backView'};
   } else {
        return undef;
   }
}

# Method: linkToView
#
#   Return the link to the model's view
#
# Returns:
#
#   string - containing the link
#   
sub linkToView
{
    my ($self) = @_;

    my $view = $self->view();
    my $directory = $self->directory();

    my $backview = $self->backView();
    my $params="?directory=$directory" . "&backview=$backview";
    
    my $printableName = $self->printableName();
    my $url = $view . $params;

    return $url;
}

# Method: foreignModelAcquirer
#
#      Get the function which has the possibility to get foreign model
#      which represents the class dynamically. It also fills the view
#      to show the model.
#
# Returns:
#
#      function ref - the reference to the callback function
#
sub foreignModelAcquirer
  {

      my ($self) = @_;

      # This function is called at the _restoreFromHash
      return $self->{'foreignModelAcquirer'};

  }

sub paramExist
{

}



sub setMemValue
{

}

sub _memValue
{

}

sub compareToHash
{

}

sub isEqualTo
{

}

sub modelView
{
    my ($self) = @_;
    return $self->{'modelView'};	
}

# Group: Protected methods

# Method: _storeInGConf
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInGConf>
#
sub _storeInGConf
{

}

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_restoreFromHash>
#
sub _restoreFromHash
  {

      my ($self, $hashRef) = @_;

      if ( defined ( $self->foreignModelAcquirer() )) {
          my $acquirerFunc = $self->foreignModelAcquirer();
          $self->{'foreignModel'} = $acquirerFunc->($hashRef);
          try {
              my $model = $self->foreignModelInstance();
              if (not $model) {
                  throw  EBox::Exceptions::DataNotFound();
              }


              $self->{'view'} = '/ebox/' . $model->menuNamespace();
              $self->setDirectory($model->directory());
          } catch EBox::Exceptions::DataNotFound with {
              $self->{'view'} = '/ebox/';
          };
      }

  }

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
  {

      return 1;

  }

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsSet>
#
sub _paramIsSet
  {

      return 1;

  }

# Method: filesPaths
#
#   Returns:
#     the paths of the files managed by the submodel and possible rows and sub-submodels
sub filesPaths
{
    my ($self) = @_;
    my $subModel = $self->foreignModelInstance();
    if (not $subModel) {
        return [];
    }

    if ($subModel->can('filesPaths')) {
        return $subModel->filesPaths();
    }
    else {
        return []
    }
}

# Method: backupFiles
#
#   Make an actual configuration backup of all the files contained in the
#   submodel and potentials rows and nested submodels. This backup will used to discard changes if needed
sub backupFiles
{
  my ($self) = @_;

  my $subModel = $self->foreignModelInstance();
  if (not $subModel) {
      return;
  }

  if ($subModel->can('backupFiles')) {
      return $subModel->backupFiles();
  }

}

# Method: restoreFiles
#
#  Restores the actual configuration backup of files, thus discarding last
#  changes in files
sub restoreFiles
{
  my ($self) = @_;

  my $subModel = $self->foreignModelInstance();
  if (not $subModel) {
      return;
  }

  if ($subModel->can('restoreFiles')) {
      return $subModel->restoreFiles();
  }
}



1;
