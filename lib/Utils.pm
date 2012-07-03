package Utils;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Math;
use Stats;
use Exporter qw(import);

our @EXPORT = qw(union inter fc_matrix si_matrix homogene is_robust);

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
# Retourne le FC du groupe de sonde et sa p_value à partir d'une matrice de fcs
# ==============================================================================

sub fc_matrix{

	my($ref_matrix_fcs) = @_;

	# Pour chaque sonde on récupère la médiane de ses fcs
	my @fcs = map { median(@{$_}) } @{$ref_matrix_fcs};

	# On calcule le fc du groupe (médiane des médianes de fc)
	my $fc = median(@fcs);

	# On fait le test stat
	my $p_value = ttest([log2(@fcs)], (log2($fc) >= 0));

	# On retourne le fc et le test stat
	return($fc, $p_value);

}

# ==============================================================================
# Prend une matrice de valeurs (sondes x num replicat)
# Permet de calculer les fcs du gène par réplicat
# ==============================================================================

sub si_matrix{

	my($ref_matrix_SIs, $paired) = @_;

	my @SIs = ();
	my @SIs_a_tester = ();

	# On récupère à l'arrach le nombre de paires de replicats
	my $nb_replicats = @{$ref_matrix_SIs->[0]};

	# Pour chaque paire de replicat
	for(my $i = 0; $i < $nb_replicats; $i++){

		my @SIs_paire_rep = map { $_->[$i] } @{$ref_matrix_SIs};

		my $SI_paire_rep = median(@SIs_paire_rep);

		push(@SIs, $SI_paire_rep);

		if($paired){

			push(@SIs_a_tester, $SI_paire_rep);

		}else{

			push(@SIs_a_tester, @SIs_paire_rep);

		}

	}

	my $SI = median(@SIs);

	my $p_value = ttest([log2(@SIs_a_tester)], (log2($SI) >= 0));

	return($SI, $p_value, @SIs);

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
