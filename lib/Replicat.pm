package Replicat;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Math;
use Utils;

sub new{

	my($class, $ref_samples) = @_;

	bless($ref_samples, $class);

	return $ref_samples;

}

sub dabg{

	my($ref_samples, $sonde, $seuil) = @_;

	my $nb_exp = 0;

	foreach my $sample (@{$ref_samples}){

		# Valeur dabg divisé par 10000 (pour avoir le float)
		my $dabg = $sonde->{$sample}/10000;

		$nb_exp++ if($dabg <= $seuil);

	}

	return ($nb_exp > (@{$ref_samples}/2));

}

sub lissage{

	my($ref_samples, $ref_sondes) = @_;

	# On lisse les sondes d'un réplicat
	my @sondes_lisses = @{$ref_sondes};

	# Pour chaque sample
	foreach my $sample (@{$ref_samples}){

		# On récupèreles sondes du sample courant
		my @valeurs_sample = map {
			$_->{$sample}
		} @{$ref_sondes};

		# On calcule la médiane et la sd du sample
		my $mean = mean(@valeurs_sample);
		my $sd = sd(@valeurs_sample);

		# On lisse les sondes du sample
		my @sondes_lisses_sample = grep {
			abs($_->{$sample} - $mean) <= $sd
		} @{$ref_sondes};

		# On garde l'intersection avec les autres samples
		@sondes_lisses = inter(
			\@sondes_lisses_sample,
			\@sondes_lisses
		);

	}

	# On retourne les sondes lisses du réplicat
	return @sondes_lisses;

}

sub expressions{

	my($ref_samples, $ref_sondes) = @_;

	my @medians = ();

	foreach my $sonde (@{$ref_sondes}){

		push(@medians, median(map { $sonde->{$_} } @{$ref_samples}));

	}

	return median(@medians);

}

sub fcs_sonde{

	my($ref_samples, $sonde) = @_;

	return [mean(map {$sonde->{$_}} @{$ref_samples})];

}

1;
