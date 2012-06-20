package Analyse;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Math;
use Stats;
use Exporter qw(import);

our @EXPORT = qw(get_infos_analyse dabg lissage_transcription lissage_epissage
	expressions fcs_sonde fcs_sondes fc_gene sis_sonde sis_sondes si_entite
	homogene is_robust);

# ==============================================================================
# Retourne un hash avec toutes les infos sur l'analyse correspondant à l'id
# passé en paramètre
# ==============================================================================

sub get_infos_analyse{

	my($dbh, $id_analyse) = @_;

	# On selectionne les infos de l'analyse
	my $select_infos_analyse_sth = $dbh->prepare(
		"SELECT a.id, p.id AS id_project, p.type AS type_chips,
		a.version, p.organism, a.type, a.paired
		FROM analyses AS a, projects AS p
		WHERE a.id_project = p.id
		AND a.id = ?"
	);

	# On selectionne les infos de l'analyse
	$select_infos_analyse_sth->execute($id_analyse);
	my $infos_analyse = $select_infos_analyse_sth->fetchrow_hashref;
	$select_infos_analyse_sth->finish;

	# On retourne undef si il n'y a pas d'analyse correspondant à l'id
	return undef if(!$infos_analyse);

	# On selectionne les puces de l'analyse
	my $select_chips_sth = $dbh->prepare(
		"SELECT g.letter, c.condition, c.num
		FROM analyses AS a, chips AS c, groups AS g
		WHERE a.id_project = c.id_project
		AND a.id = g.id_analysis
		AND c.condition = g.condition
		AND a.id = ?
		ORDER BY num ASC"
	);

	# On défini les conditions de l'analyse
	my $nb_paires_rep = 0;
	my $conditions = {};

	# On selectionne les puces
	$select_chips_sth->execute($infos_analyse->{'id'});

	# Pour chaque puces
	while(my($letter, $condition, $num) = $select_chips_sth->fetchrow_array){

		# On compte le nombre de paires de replicats
		$nb_paires_rep++ if($num > $nb_paires_rep);

		# On défini le nom du sample
		my $sample = $condition . '_' . $num;

		# On ajoute au sample
		if(!$conditions->{$letter}){

			$conditions->{$letter} = [$sample];

		}else{

			push(@{$conditions->{$letter}}, $sample);

		}

	}

	$infos_analyse->{'conditions'} = $conditions;

	# On calcule le nombre de paires de replicats
	$infos_analyse->{'nb_paires_rep'} = ($infos_analyse->{'paired'})
		? @{$infos_analyse->{'conditions'}->{'A'}}
		: 1;

	# On défini le design de l'expérience
	my $design = [];

	# Selon que l'analyse soit simple ou composée, ça change...
	if($infos_analyse->{'type'} eq 'simple'){

		# Pour chaque paire de replicat
		for(my $i = 0; $i < $infos_analyse->{'nb_paires_rep'}; $i++){

			$design->[$i] = {
				'control' => ($infos_analyse->{'paired'})
					? [@{$infos_analyse->{'conditions'}->{'A'}}[$i]]
					: $infos_analyse->{'conditions'}->{'A'},
				'test' => ($infos_analyse->{'paired'})
					? [@{$infos_analyse->{'conditions'}->{'B'}}[$i]]
					: $infos_analyse->{'conditions'}->{'B'} 
			};

		}

	}else{

		# Analyse de type composée, on récupère les sous comparaisons
		my $control = [];
		my $test = [];

		# Pour chaque paire de replicat
		for(my $i = 0; $i < $infos_analyse->{'nb_paires_rep'}; $i++){

			$control->[$i] = {
				'control' => ($infos_analyse->{'paired'})
					? [@{$infos_analyse->{'conditions'}->{'A'}}[$i]]
					: $infos_analyse->{'conditions'}->{'A'},
				'test' => ($infos_analyse->{'paired'})
					? [@{$infos_analyse->{'conditions'}->{'B'}}[$i]]
					: $infos_analyse->{'conditions'}->{'B'} 
			};

			$test->[$i] = {
				'control' => ($infos_analyse->{'paired'})
					? [@{$infos_analyse->{'conditions'}->{'C'}}[$i]]
					: $infos_analyse->{'conditions'}->{'C'},
				'test' => ($infos_analyse->{'paired'})
					? [@{$infos_analyse->{'conditions'}->{'D'}}[$i]]
					: $infos_analyse->{'conditions'}->{'D'} 
			};

		}

		# On intègre les sous comparaisons à la comparaison globale
		$design->[0] = {
			'control' => bless($control, 'Design'),
			'test' => bless($test, 'Design')
		};

	}

	$infos_analyse->{'design'} = bless($design, 'Design');

	# On retourne les infos
	return $infos_analyse;

}

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

	return \@union;

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

	return \@inter;

}

# ==============================================================================
# Retourne vrai si la sonde passe le seuil du dabg dans au moins la moitiée
# des puces d'au moins une condition
# ==============================================================================

sub dabg{

	my($ref_design, $sonde, $seuil) = @_;

	# On reçoit soit un design, soit une liste de samples
	if(ref($ref_design) eq 'Design'){

		# On calcule combien de reps controle et de rep tests sont
		# exprimés
		my $nb_reps = @{$ref_design};
		my $nb_exp_cont = 0;
		my $nb_exp_test = 0;

		# Pour chaque paire de replicats
		foreach my $paire (@{$ref_design}){

			# On calcule si la sonde est exprimée dans controle et
			# si elle est exprimé dans test
			$nb_exp_cont++ if(dabg($paire->{'control'}, $seuil, $sonde));
			$nb_exp_test++ if(dabg($paire->{'test'}, $seuil, $sonde));

		}

		# Si exprimée dans la moitié des reps controle ou la moitié des
		# reps test, on retourne true
		return ($nb_exp_cont > ($nb_reps/2) or $nb_exp_test > ($nb_reps/2));

	}else{

		# On retourne l'expression de la sonde dans ce réplicat
		return dabg_replicat($ref_design, $sonde, $seuil);

	}

}

# ==============================================================================
# Retourne le dabg sur un replicat
# ==============================================================================

sub dabg_replicat{

	my($ref_samples, $seuil, $sonde) = @_;

	my $nb_exp = 0;

	foreach my $sample (@{$ref_samples}){

		# Valeur dabg divisé par 10000 (pour avoir le float)
		my $dabg = $sonde->{$sample}/10000;

		$nb_exp++ if($dabg <= $seuil);

	}

	return ($nb_exp > (@{$ref_samples}/2));

}

# ==============================================================================
# Retourne une liste de sondes lissées pour la transcription
# ==============================================================================

sub lissage{

	my($ref_design, $ref_sondes, $ref_func_aggr) = @_;

	if(ref($ref_design) eq 'Design'){

		my @sondes_lisses_cont = @{$ref_sondes};
		my @sondes_lisses_test = @{$ref_sondes};

		foreach my $paire (@{$ref_design}){

			my @sondes_lisses_cont_rep = lissage(
				$paire->{'control'},
				$ref_sondes,
				$ref_func_aggr
			);

			my @sondes_lisses_test_rep = lissage(
				$paire->{'test'},
				$ref_sondes,
				$ref_func_aggr
			);

			@sondes_lisses_cont = inter(
				\@sondes_lisses_cont,
				\@sondes_lisses_cont_rep
			);

			@sondes_lisses_test = inter(
				\@sondes_lisses_test,
				\@sondes_lisses_test_rep
			);

		}

		return $ref_func_aggr->(
			\@sondes_lisses_cont,
			\@sondes_lisses_test
		);

	}else{

		return lissage_replicat($ref_design, $ref_sondes);

	}

}

# ==============================================================================
# Retourne les sondes lissées sur un réplicat
# ==============================================================================

sub lissage_replicat{

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
		my @sondes_lisses_sample = [grep {
			abs($_->{$sample} - $mean) <= $sd
		} @{$ref_sondes}];

		# On garde l'intersection avec les autres samples
		my $ref_sondes_lisses = inter(
			\@sondes_lisses_sample,
			\@sondes_lisses
		);

	}

	# On retourne les sondes lisses du réplicat
	return @sondes_lisses;

}

# ==============================================================================
# Lissage pour la transcription et pour l'épissage
# ==============================================================================

sub lissage_transcription{

	my($ref_design, $ref_sondes) = @_;

	return lissage($ref_design, $ref_sondes, \&union);

}

sub lissage_epissage{

	my($ref_design, $ref_sondes) = @_;

	return lissage($ref_design, $ref_sondes, \&inter);

}

# ==============================================================================
# Calcul de l'expression d'une liste de sonde
# ==============================================================================

# Retourne les valeurs d'expression d'un groupe de sonde
# (mediane de tout les samples d'un réplicat puis médiane de ces valeurs
# => une valeur par replicat)
sub expressions{

	my($ref_design, $ref_sondes) = @_;

	if(ref($ref_design) eq 'Design'){

		my @expressions = ();

		foreach my $paire (@{$ref_design}){

			push(@expressions, expressions(
				$paire->{'control'},
				$ref_sondes
			));

			push(@expressions, expressions(
				$paire->{'test'},
				$ref_sondes
			));

		}

		return @expressions;

	}else{

		return expression_replicat($ref_design, $ref_sondes);

	}

}

# ==============================================================================
# Retourne l'expression d'un réplicat
# ==============================================================================

sub expression_replicat{

	my($ref_samples, $ref_sondes) = @_;

	my @medians = ();

	foreach my $sonde (@{$ref_sondes}){

		push(@medians, median(map { $sonde->{$_} } @{$ref_samples}));

	}

	return median(@medians);

}

# ==============================================================================
# Retourne tous les fcs d'une sonde, un par paire de replicat
# ==============================================================================

sub fcs_sonde{

	my($ref_design, $sonde) = @_;

	if(ref($ref_design) eq 'Design'){

		# On initialise la liste des fcs de la sonde
		my @fcs = ();

		# Pour chaque paire de replicats
		foreach my $paire (@{$ref_design}){

			# On calcule la valeur de la sonde pour control et test
			my @fcs_cont = fcs_sonde($paire->{'control'}, $sonde);
			my @fcs_test = fcs_sonde($paire->{'test'}, $sonde);

			# On fait tout les fcs de cette paire de replicat
			for(my $i = 0; $i < @fcs_cont; $i++){

				push(@fcs, $fcs_test[$i]/$fcs_cont[$i]);

			}

		}

		# On retourne les fcs de la sonde dans chaque paire de replicats
		return @fcs;

	}else{

		# On retoure la moyenne des valeurs de la sonde sur les samples
		# du replicat
		return (mean(map {$sonde->{$_}} @{$ref_design}));
	}

}

# ==============================================================================
# Retourne la liste des FCs de chaque sonde (liste de liste)
# ==============================================================================

sub fcs_sondes{

	my($ref_design, $fc_groupe, $ref_sondes) = @_;

	my @fcs_sondes = ();

	foreach my $sonde (@{$ref_sondes}){

		my @fcs_sonde = fcs_sonde($ref_design, $fc_groupe, $sonde);

		push(@fcs_sondes, \@fcs_sonde);

	}

	return @fcs_sondes;

}

# ==============================================================================
# Retourne le FC du groupe de sonde et sa p_value
# ==============================================================================

sub fc_gene{

	my($ref_design, $ref_sondes) = @_;

	# Pour chaque sonde on récupère la médiane de ses fcs
	my @fcs_sondes = map {
		median(fcs_sonde($ref_design, $_))
	} @{$ref_sondes};

	# On calcule le fc du groupe (médiane de ces médianes de fc)
	my $fc = median(@fcs_sondes);

	# On fait le test stat
	my $p_value = ttest((log2($fc) >= 0), log2(@fcs_sondes));

	# On retourne le fc et le test stat
	return($fc, $p_value);

}

# ==============================================================================
# Retourne la liste des SIs d'une sonde (une par paire de replicat)
# ==============================================================================

sub sis_sonde{

	my($ref_design, $fc_groupe, $sonde) = @_;

	my @SIs = ();

	my @fcs = fcs_sonde($ref_design, $sonde);

	foreach(@fcs){ push(@SIs, ($_/$fc_groupe)) }

	return @SIs;

}

# ==============================================================================
# Retourne la liste des SIs de chaque sonde (liste de liste)
# ==============================================================================

sub sis_sondes{

	my($ref_design, $fc_groupe, $ref_sondes) = @_;

	my @SIs_sondes = ();

	foreach my $sonde (@{$ref_sondes}){

		my @SIs_sonde = sis_sonde($ref_design, $fc_groupe, $sonde);

		push(@SIs_sondes, \@SIs_sonde);

	}

	return @SIs_sondes;

}

# ==============================================================================
# Retourne le SI du groupe de sonde et sa p_value
# ==============================================================================

sub si_entite{

	my($ref_design, $ref_SIs_sondes, $paired) = @_;

	my @SIs = ();
	my @SIs_a_tester = ();

	# On récupère à l'arrach le nombre de paires de replicats
	my $nb_replicats = @{$ref_SIs_sondes->[0]};

	# Pour chaque paire de replicat
	for(my $i = 0; $i < $nb_replicats; $i++){

		my @SIs_paire_rep = map { $_->[$i] } @{$ref_SIs_sondes};

		my $SI_paire_rep = median(@SIs_paire_rep);

		push(@SIs, $SI_paire_rep);

		if($paired){

			push(@SIs_a_tester, $SI_paire_rep);

		}else{

			push(@SIs_a_tester, @SIs_paire_rep);

		}

	}

	my $SI = median(@SIs);

	my $p_value = ttest((log2($SI) >= 0), log2(@SIs_a_tester));

	return($SI, $p_value, @SIs);

}

# ==============================================================================
# Retourne si un groupe de sondes est homogene ou non
# ==============================================================================

sub homogene{

	my($infos_sondes, $ref_sondes, $nb_exons, $nb_exons_min,$nb_min_par_exon) = @_;

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

	my($ref_SIs, $seuil_si, $seuil_percent, $seuil_nb_sondes_min) = @_;

	my $nb_SIs = @{$ref_SIs};
	my $nb_ups = 0;
	my $nb_downs = 0;

	# Pour chaque si
	foreach my $SI (@{$ref_SIs}){

		# On compte les SIs up et les SIs down
		if($SI >= $seuil_si){ $nb_ups++; }
		if((1/$SI) >= $seuil_si){ $nb_downs++; }

	}

	# On récupère la limite
	my $limit = int($nb_SIs*$seuil_percent);

	# On regarde si l'entité est globalement up ou down
	my $is_up = ($nb_ups >= $limit and $nb_ups >= $seuil_nb_sondes_min);
	my $is_down = ($nb_downs >= $limit and $nb_downs >= $seuil_nb_sondes_min);

	# Si l'entité est up ou down, elle est robuste
	return ($is_up or $is_down);

}

1;
