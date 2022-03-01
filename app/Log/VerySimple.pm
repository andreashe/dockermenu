package Log::VerySimple;
 
 
use strict;
 
use vars qw(@ISA @EXPORT %EXPORT_TAGS $VERSION);
use Exporter; 
 
our $VERSION='0.05';
 
 
@ISA = qw(Exporter);
 
%EXPORT_TAGS = ( all => [qw(
                      LOG
                )] ); 
 
Exporter::export_ok_tags('all'); 

# constructor
sub new{
    return bless {}, shift; # blessing on the hashed 
}
  


# singleton with constructor
sub LOG{
  my $self = $__PACKAGE__::SINGLETON;

  if ($self != undef){return $self}
  $self = new Log::VerySimple();
  $__PACKAGE__::SINGLETON = $self;
  
  return $self;
}


sub debug{
  my $self = shift;
  my $msg = shift;

  print "$msg\n";
}

sub info{
  my $self = shift;
  my $msg = shift;

  print "$msg\n";
}

sub warning{
  my $self = shift;
  my $msg = shift;

  print "$msg\n";
}




1;