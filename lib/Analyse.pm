package Analyse;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Design;
use Math;
use Exporter qw(import);

our @EXPORT = qw(get_infos_analyse get_design dabg lissage_transcription
	lissage_epissage expressions fcs_sondes fcs_sonde sis_sonde);

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
	my $conditions = {};

	# On selectionne les puces
	$select_chips_sth->execute($infos_analyse->{'id'});

	# Pour chaque puces
	while(my($letter, $condition, $num) = $select_chips_sth->fetchrow_array){

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

	# On récupère le design de l'analyse
	$infos_analyse->{'design'} = get_design($infos_analyse);

	# On retourne les infos
	return $infos_analyse;

}

# ==============================================================================
# Retourne le design d'une analyse
# ==============================================================================

sub get_design{

	my($infos_analyse) = @_;

	# On défini le design de l'expérience
	my $design = [];

	# On calcule le nombre de paires de replicats
	my $nb_paires_replicats = ($infos_analyse->{'paired'})
		? @{$infos_analyse->{'conditions'}->{'A'}}
		: 1;

	# Pour chaque paire de replicat
	for(my $i = 0; $i < $nb_paires_replicats; $i++){

		$design->[$i] = {
			'control' => ($infos_analyse->{'paired'})
				? [@{$infos_analyse->{'conditions'}->{'A'}}[$i]]
				: $infos_analyse->{'conditions'}->{'A'},
			'test' => ($infos_analyse->{'paired'})
				? [@{$infos_analyse->{'conditions'}->{'B'}}[$i]]
				: $infos_analyse->{'conditions'}->{'B'} 
		};

	}

	return new Design($design);

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
# Retourne vrai si la sonde passe le seuil du dabg dans au moins la moitiée
# des puces d'au moins une condition
# ==============================================================================

sub dabg{

	my($ref_conditions, $seuil, $sonde) = @_;

	# Pour chaque condition
	foreach(keys %{$ref_conditions}){

		my $nb_exp_cond = 0;

		# Pour chaque sample
		foreach my $sample (@{$ref_conditions->{$_}}){

			# valeur dabg divisé par 10000 (pour avoir le float)
			my $dabg = $sonde->{$sample}/10000;

			if($dabg <= $seuil){ $nb_exp_cond++; }

		}

		# Si la sonde est exprimée dans plus de la moitié des samples de
		# la condition on la garde
		if($nb_exp_cond > (@{$ref_conditions->{$_}}/2)){

			return 1;

		}

	}

	return 0;

}

# ==============================================================================
# Retourne une liste de sondes lissées pour la transcription
# ==============================================================================

# Filtre une liste de sondes par un lissage de type transcription
# Cad on garde les sondes dont l'intensité est comprise dans la moyenne plus ou
# moins l'écart type des intensités de chaque réplicat d'AU MOINS une condition
sub lissage_transcription{

	my($ref_conditions, $ref_sondes) = @_;

	# A priori il y en a aucune, on les ajoute au fur et a mesure
	my @sondes_lisses = ();

	# Pour chaque condition
	foreach(keys %{$ref_conditions}){

		# On lisse les sondes de cette condition
		my @sondes_condition = lissage_condition(
			$ref_conditions->{$_},
			$ref_sondes
		);

		# On fait l'union des sondes déjà présentes et de celles qui
		# passent le lissage pour cette condition
		@sondes_lisses = union(\@sondes_lisses, \@sondes_condition);

	}

	return @sondes_lisses;

}

# ==============================================================================
# Retourne une liste de sondes lissées pour l'épissage
# ==============================================================================

# Filtre une liste de sondes par un lissage de type épissage
# Cad on garde les sondes dont l'intensité est comprise dans la moyenne plus ou
# moins l'écart type des intensités de chaque réplicat DE TOUTES les conditions
# (cad de tous les réplicats)
sub lissage_epissage{

	my($ref_conditions, $ref_sondes) = @_;

	# On prend toutes les sondes et on les élimines au fur et a mesure
	my @sondes_lisses = @{$ref_sondes};

	# Pour chaque conditions
	foreach (keys %{$ref_conditions}){

		# On lisse les sondes de cette condition
		my @sondes_condition = lissage_condition(
			$ref_conditions->{$_},
			$ref_sondes
		);

		# On fait l'intersection des sondes déjà presentes et de celles
		# qui passent le lissage pour cette condition
		@sondes_lisses = inter(\@sondes_lisses, \@sondes_condition);

	}

	# On retourne la liste des sondes lisses
	return @sondes_lisses;

}

# ==============================================================================
# Retourne les sondes lissées sur une condition
# ==============================================================================

sub lissage_condition{

	my($ref_condition, $ref_sondes) = @_;

	# A priori toutes les sondes sont ok et on les élimine
	my @sondes_lisses = @{$ref_sondes};

	# Pour chaque sample de la condition
	foreach my $sample (@{$ref_condition}){

		# On récupère les valeurs des sondes pour ce sample
		my @valeurs_sample = map { $_->{$sample} } @{$ref_sondes};

		# On calcule la moyenne et la sd de ce sample
		my $mean = mean(@valeurs_sample);
		my $sd = sd(@valeurs_sample);

		# On garde seulement les sondes comprise dans la moyenne
		# + / - la sd
		@sondes_lisses = grep {
			abs($_->{$sample} - $mean) <= $sd
		} @sondes_lisses;

	}

	return @sondes_lisses;

}

# ==============================================================================
# Calcul de l'expression d'une liste de sonde
# ==============================================================================

# Retourne les valeurs d'expression d'un groupe de sonde
# (mediane de tout les samples d'un réplicat puis médiane de ces valeurs
# => une valeur par replicat)
sub expressions{

	my($ref_design, $ref_sondes) = @_;

	my @expressions = ();

	foreach my $paire (@{$ref_design}){

		push(@expressions, expressions_replicat($paire->{'control'}, $ref_sondes));
		push(@expressions, expressions_replicat($paire->{'test'}, $ref_sondes));

	}

	return @expressions;

}

# ==============================================================================
# Retourne les valeurs d'expression d'un replicat
# ==============================================================================

sub expressions_replicat{

	my($ref_design, $ref_sondes) = @_;

	my @expressions = ();

	if(ref($ref_design) eq 'Design'){

		push(@expressions, expressions($ref_design, $ref_sondes));

	}else{

		my @medians = ();

		foreach my $sonde (@{$ref_sondes}){

			push(@medians, median(map { $sonde->{$_} } @{$ref_design}));

		}

		push(@expressions, median(@medians));

	}

	return @expressions;

}

# ==============================================================================
# Fonctions pour le fold change (utilitée de cette fonction ??)
# ==============================================================================

# Retourne la liste des médianes des fold changes d'un groupe de sonde
sub fcs_sondes{

	my($ref_design, $ref_sondes) = @_;

	my @fcs = ();

	foreach my $sonde (@{$ref_sondes}){

		# On calcule la médiane des fc des replicats (dans le cas d'une
		# exp impaire, il n'y en a qu'un, donc faire la médiane change
		# rien)
		push(@fcs, median(fcs_sonde($ref_design, $sonde)));

	}

	return @fcs;

}

# ==============================================================================
# Retourne tous les fold change d'une sonde
# (=> un par paire de replicat)
# ==============================================================================

sub fcs_sonde{

	my($ref_design, $sonde) = @_;

	my @fcs_replicats = ();

	# Un compteur pour toutes les paires
	foreach my $paire (@{$ref_design}){

		# On récupère la valeur de la sonde pour ce replicat
		# => moyenne des samples si exp non paire
		# => fold change des deux sous condition si composée
		my $valeur_control = valeur_somme_sonde($paire->{'control'}, $sonde);
		my $valeur_test = valeur_somme_sonde($paire->{'test'}, $sonde);

		# On ajoute le fc du replicat a la liste des fc des replicats
		push(@fcs_replicats, ($valeur_test/$valeur_control));

	}

	return @fcs_replicats;

}

# ==============================================================================
# Retourne une valeur unique de la sonde pour un design donné
# ==============================================================================

sub valeur_somme_sonde{

	my($ref_design, $sonde) = @_;

	if(ref($ref_design) eq 'Design'){

		return mean(fcs_sonde($ref_design, $sonde));
		# => Fait toujours la moyenne sur un seul fold change car on
		# ne fait pas (encore) de composée dont une partie est composée
		# de plusieurs exp...
		# A voir quelle bonne fonction d'agrégation utiliser ce jour là :)

	}else{

		return mean(map {$sonde->{$_}} @{$ref_design});

	}

}

# ==============================================================================
# Retourne la liste des SIs d'une sonde (une par paire de replicat)
# ==============================================================================

sub sis_sonde{

	my($ref_exp, $fc_groupe, $sonde) = @_;

	# On initialise la liste de SIs
	my @SIs = ();

	# On calcule les SIs
	# pour ça il faut récupérer les folds déjà
	my @fcs = fcs_sonde($ref_exp, $sonde);

	# Si de la sonde (cad, fc de la sonde sur fc du groupe)
	foreach(@fcs){ push(@SIs, ($_/$fc_groupe)) }

	# On retourne la liste de SIs de la sonde
	return @SIs;

}

1;
