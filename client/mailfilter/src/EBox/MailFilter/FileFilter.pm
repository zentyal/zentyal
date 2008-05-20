package EBox::MailFilter::FileFilter;
#
use strict;
use warnings;

use base qw(EBox::GConfModule::Partition);

use EBox::Gettext;

my $ESCAPED_MIME_SEPARATOR = '_';


sub new 
{
  my $class = shift @_;

  my $self = $class->SUPER::new(@_);

  bless $self, $class;

  return $self;
}


# Function: extensions
#
#	Fetch the file extensions
#
# Returns:
#
# 	Hash ref - containing the extensions as values, and a boolean which mark
# 	if it is allowed
sub extensions
{
  my ($self) = @_;
  return $self->hashFromConfDir('extensions');
}

# Function: setExtension
#
#	Set a extension
#
# Parameters:
#
# 	  - extension
#         - allowed 
sub setExtension
{
  my ($self, $extension, $allowed) = @_;
  defined $allowed or
    throw EBox::Exceptions::MissingArgument;
  defined $extension or
    throw EBox::Exceptions::MissingArgument;

  $self->_checkExtension($extension);


  $self->setConfBool("extensions/$extension", $allowed);
}

sub unsetExtension
{
  my ($self, $extension) = @_;

  my $key = "extensions/$extension";
  my $value =  $self->getConfBool($key);

  if (not defined $value) {
    throw EBox::Exceptions::External(
		       __x('{ext} is not registered in the extensions list',
			   ext => $extension)
				   )
  }

  $self->unsetConf($key)
}




# Function: MimeTypes
#
#	Fetch the  mime type list
#
# Returns:
#
# 	Hash ref - containing the mime types
sub mimeTypes
{
  my ($self) = @_;
  my %dir;

  my $escapedDir = $self->hashFromConfDir('mime_types');
  while (my($key, $value) = each %{ $escapedDir }) {
    $key = $self->_unescapeMimeType($key);
    $dir{$key} = $value;
  } 

  return \%dir;
}

# Function: setMimeType
#
#	Set the  mime type list
#
# Parameters:
#
# 	mimeType -
#       allowed  -
sub setMimeType
{
  my ($self, $mimeType, $allowed) = @_;
  defined $allowed or
    throw EBox::Exceptions::MissingArgument;
  defined $mimeType or 
    throw EBox::Exceptions::MissingArgument;


  $self->_checkMimeType($mimeType);


  $mimeType = $self->_escapeMimeType($mimeType);
  $self->setConfBool("mime_types/$mimeType", $allowed);
}

sub unsetMimeType
{
  my ($self, $mimeType) = @_;

  $mimeType = $self->_escapeMimeType($mimeType);

  my $key = "mime_types/$mimeType";
  my $value =  $self->getConfBool($key);

  if (not defined $value) {
    throw EBox::Exceptions::External(
		       __x('{ext} is not registered in the mimeTypes list',
			   ext => $mimeType)
				   )
  }

  $self->unsetConf($key)
}



sub _escapeMimeType
{
  my ($self, $mimeType) = @_;
  $mimeType =~ s{/}{$ESCAPED_MIME_SEPARATOR};

  return $mimeType;
}

sub _unescapeMimeType
{
  my ($self, $mimeType) = @_;
  $mimeType =~ s{$ESCAPED_MIME_SEPARATOR}{/};
  return $mimeType;
}




sub _checkMimeType
{
  my ($self, $mimeType) = @_;

  my $portionRegex = '[a-zA-Z\d\-]+';

  unless ($mimeType =~ m{^$portionRegex\/$portionRegex$}) {
    throw EBox::Exceptions::InvalidData (
					 data => __x('MIME type'),
					 value =>  $mimeType,
					);    
  }
}


sub _checkExtension
{
  my ($self, $extension) = @_;


  unless ($extension =~ m/^[a-zA-Z\d]+$/) {
    throw EBox::Exceptions::InvalidData (
					 data => __x('file extension'),
					 value =>  $extension,
					);
  }

}


sub bannedFilesRegexes
{
  my ($self) = @_;
  my @bannedRegexes;

  push @bannedRegexes, @{ $self->_bannedExtensionsRegexes() };
  push @bannedRegexes, @{ $self->_bannedMimeTypesRegexes() };

  return \@bannedRegexes;
}


sub _bannedExtensionsRegexes
{
  my ($self) = @_;

  my $extensions_r = $self->extensions();
  my @bannedExtensions = grep { not $extensions_r->{$_} } keys %{ $extensions_r };
  @bannedExtensions = map { '^.' . $_ . '$'  } @bannedExtensions;

  return \@bannedExtensions;
}


sub _bannedMimeTypesRegexes
{
  my ($self) = @_;

  my $mimeTypes_r = $self->mimeTypes();
  my @bannedMimeTypes = grep { not $mimeTypes_r->{$_} } keys %{ $mimeTypes_r };
  @bannedMimeTypes = map {
    $_ =~ s{/}{\/};
    '^' . $_ . '$'  

  } @bannedMimeTypes;
 

  return \@bannedMimeTypes;
}


1;


