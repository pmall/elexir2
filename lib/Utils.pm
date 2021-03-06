package Utils;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Math;
use Exporter qw(import);

our @EXPORT = qw(union inter sum_no_rep_effect sum_rep_effect rep_effect
	homogene is_robust);

# ==============================================================================
# Retourne l'union de deux listes de sondes
# ==============================================================================

sub union{

	my($ref_sondes1, $ref_sondes2) = @_;

	my @union = @{$ref_sondes1};

	# On récupère les ids des probes déjà dans l'union
	my @ids_sondes = map {$_->{'probe_id'}} @union;

	foreach my $sonde (@{$ref_sondes2}){

		if(!($sonde->{'probe_id'} ~~ @ids_sondes)){

			push(@union, $sonde);

		}

	}

	return @union;

}

# ==============================================================================
# Retourne l'intersection de deux listes de sondes
# ==============================================================================

sub inter{

	my($ref_sondes1, $ref_sondes2) = @_;

	my @inter = ();

	# On récupère les ids des probes déjà dans l'union
	my @ids_sondes = map {$_->{'probe_id'}} @{$ref_sondes1};

	foreach my $sonde (@{$ref_sondes2}){

		if($sonde->{'probe_id'} ~~ @ids_sondes){

			push(@inter, $sonde);

		}

	}

	return @inter;

}

# ==============================================================================
# Retourne la valeur sommée et les valeurs à utiliser pour le test (valeurs
# medianes pour chaque sonde) à partir d'une matrice (sondes x valeur)
# PAS D'EFFET REPLICAT
# ==============================================================================

sub sum_no_rep_effect{

	my($ref_matrix) = @_;

	# Pour chaque sonde on récupère la médiane des valeurs
	my @valeurs_a_tester = map { median(@{$_}) } @{$ref_matrix};

	# La valeur somme est la médiane des valeurs à tester
	my $sum = median(@valeurs_a_tester);

	# On retourne les deux
	return($sum, @valeurs_a_tester);

}

# ==============================================================================
# Retourne la valeur sommée et les valeurs à utiliser pour le test (valeurs
# medianes de chaque replicat) à partir d'une matrice (sondes x valeur)
# AVEC EFFET REPLICAT
# => Inutile d'utiliser ça sur une exp non paire.
# => Pour une exp non paire utiliser sum_no_rep_effect
# ==============================================================================

sub rep_effect{

	my($ref_matrix) = @_;

	# On initialise les valeurs à tester
	my @valeurs_reps = ();

	# On récupère le nombre de colones de la matrice
	my $nb_cols = @{$ref_matrix->[0]};

	# Pour chaque colones
	for(my $i = 0; $i < $nb_cols; $i++){

		# On récupère les valeurs de cette colonne
		my @valeurs_col = map { $_->[$i] } @{$ref_matrix};

		# On ajoute la médiane de la colonne aux valeurs à tester
		push(@valeurs_reps, median(@valeurs_col));

	}

	# On retourne les valeurs des rep
	return \@valeurs_reps;

}

sub sum_rep_effect{

	my($ref_matrix) = @_;

	# On initialise les valeurs à tester
	my $ref_valeurs_a_tester = rep_effect($ref_matrix);

	# La valeur somme est la médiane des valeurs à tester
	my $sum = median(@{$ref_valeurs_a_tester});

	# On retourne les deux
	return($sum, @{$ref_valeurs_a_tester});

}

# ==============================================================================
# Retourne si un groupe de sondes est homogene ou non
# ==============================================================================

sub homogene{

	my($infos_sondes, $ref_sondes, $nb_exons, $nb_exons_min, $nb_min_par_exon) = @_;

	# Valeurs par défaut
	$nb_exons_min //= 4; #/
	$nb_min_par_exon //= 2; #/

	# Si il y a moin de $nb_exons_min exons, on retourne true
	return 1 if($nb_exons < $nb_exons_min);

	# On compte le nombre de sondes par exon
	my %sondes_par_exons = ();

	foreach my $sonde (@{$ref_sondes}){

		$sondes_par_exons{$infos_sondes->{$sonde->{'probe_id'}}->{'exon_pos'}}++;

	}

	# On récupère le nombre d'exons qui sont ciblés par au moins
	# deux sondes
	my $nb_exons_2_sondes = grep {
		$sondes_par_exons{$_} >= $nb_min_par_exon
	} keys %sondes_par_exons;

	# On met a jour le booleen homogene
	return ($nb_exons_2_sondes >= int($nb_exons/2));

}

# ==============================================================================
# Retourne vrai si la liste de SIs est cohérente
# ==============================================================================

sub is_robust{

	my($ref_values, $seuil_up, $seuil_down, $seuil_percent, $seuil_nb_sondes_min) = @_;

	# Valeurs par défaut
	$seuil_percent //= 0.8; #/
	$seuil_nb_sondes_min //= 3; #/

	my $nb_values = @{$ref_values};
	my $nb_ups = 0;
	my $nb_downs = 0;

	# Pour chaque si
	foreach my $value (@{$ref_values}){

		# On compte les SIs up et les SIs down
		if($value >= $seuil_up){ $nb_ups++; }
		if($value <= $seuil_down){ $nb_downs++; }

	}

	# On récupère la limite
	my $limit = int($nb_values*$seuil_percent);

	# On regarde si l'entité est globalement up ou down
	my $is_up = ($nb_ups >= $limit and $nb_ups >= $seuil_nb_sondes_min);
	my $is_down = ($nb_downs >= $limit and $nb_downs >= $seuil_nb_sondes_min);

	# Si l'entité est up ou down, elle est robuste
	return ($is_up or $is_down);

}
