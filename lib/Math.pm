package Math;
use strict;
use warnings;
use List::Util qw(sum);
use Exporter qw(import);

our @EXPORT = qw(mean variance sd sd_est median log2 round);

# ==============================================================================
# Fonctions stats descriptive
# ==============================================================================

sub round{

	my($value, $nb_decimals) = @_;

	return sprintf('%0.' . $nb_decimals . 'f', $value);

}

sub mean{

	return sum(@_)/@_;

}

sub variance{

	my $mean = mean(@_);

	# Somme des écarts a la moyenne au carré
	my $sum_diffs_squared = sum(map { (($_ - $mean)**2) } @_);

	return $sum_diffs_squared/@_;
}

sub sd{

	# On retourne la racine carrée de la variance
	return ((variance(@_))**0.5);

}

sub sd_est{

	# On calcule le coeff pour l'estimation sur la population
	my $cor = @_/(@_-1);

	# On retourne la racine carrée de la variance corrigée
	return ((variance(@_)*$cor)**0.5);

}

sub median{

	# On classe les valeurs par ordre croissant
	my @ordered = sort {$a <=> $b} @_;

	return (@_ % 2)
		? $ordered[int(@_/2)]
		: (($ordered[(@_/2) - 1] + $ordered[@_/2]) / 2);

}

sub log2{

	my($ref_values) = @_;

	my $v = [];

	if(ref($ref_values) eq 'ARRAY'){

		$v = $ref_values;

	}else{

		push(@{$v}, $ref_values);

	}

	for(my $i; $i < @{$v}; $i++){ $v->[$i] = log($v->[$i])/log(2); }

	return $v;

}

1;
