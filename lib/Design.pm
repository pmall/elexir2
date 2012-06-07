package Design;
use strict;
use warnings;

sub new{

	my($class, $data) = @_;

	bless($data);

	return $data;

}

1;
