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
		"SELECT p.id AS id_project, p.type AS type_chips, a.version, p.organism, a.type
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

	# On décrit l'expérience
	($infos_analyse->{'design'}, $infos_analyse->{'conditions'}) = get_design(
		$dbh,
		$id_analyse,
		$infos_analyse->{'type'}
	);

	# On retourne les infos
	return $infos_analyse;

}

# ==============================================================================
# Retourne un hash avec toutes les infos sur l'analyse correspondant à l'id
# passé en paramètre
# ==============================================================================

sub get_design{

	my($dbh, $id_analyse, $type_analyse) = @_;

	# On selectionne les conditions du projet
	my $select_chips_sth = $dbh->prepare(
		"SELECT g.letter, c.condition, c.num
		FROM analyses AS a, chips AS c, groups AS g
		WHERE a.id_project = c.id_project
		AND a.id = g.id_analysis
		AND c.condition = g.condition
		AND a.id = ?"
	);

	# On fait le design de l'exp et les samples

	# On défini le nom des condition
	my %letter2type = ('A' => 'control', 'B' => 'test');
	my $design = [];
	my $conditions = {};

	$select_chips_sth->execute($id_analyse);

	while(my($letter, $condition, $num) = $select_chips_sth->fetchrow_array){

		# On défini le nom du sample
		my $sample = $condition . '_' . $num;

		# On ajoute au sample
		if(!$conditions->{$letter}){

			$conditions->{$letter} = [$sample];

		}else{

			push(@{$conditions->{$letter}}, $sample);

		}

		# On ajoute au design
		my $type = $letter2type{$letter};

		if($type_analyse eq 'paire'){

			if(!$design->[$num - 1]){

				$design->[$num - 1] = { $type => [$sample] };

			}else{

				$design->[$num - 1]->{$type} = [$sample];

			}

		}else{

			if(!$design->[0]){

				$design->[0] = { 'control' => [], 'test' => [] };

			}

			push(@{$design->[0]->{$type}}, $sample);

		}

	}

	return(new Design($design), $conditions);

}

# ==============================================================================
# Calcul de l'expression d'une sonde a partir du dabg
# ==============================================================================

# Retourne 1 si la sonde est exprimée dans au moins la moitié des replicats
# d'au moins une condition, 0 sinon
sub dabg{

	my($ref_design, $seuil, $sonde) = @_;

	my $nb_control = 0;
	my $nb_test = 0;
	my $nb_exp_control = 0;
	my $nb_exp_test = 0;

	foreach my $paire (@{$ref_design}){

		foreach(@{$paire->{'control'}}){

			$nb_control++;

			# valeur dabg divisé par 10000 (pour avoir le float)
			my $dabg = $sonde->{$_}/10000;

			if($dabg <= $seuil){ $nb_exp_control++; }

		}

		foreach(@{$paire->{'test'}}){

			$nb_test++;

			# valeur dabg divisé par 10000 (pour avoir le float)
			my $dabg = $sonde->{$_}/10000;

			if($dabg <= $seuil){ $nb_exp_test++; }

		}

	}

	# On retourne 1 si la sonde est exprimée dans la moitié des réplicats
	# d'au moins une condition
	my $exp_control = $nb_exp_control > ($nb_control/2);
	my $exp_test = $nb_exp_test > ($nb_test/2);

	return ($exp_control or $exp_test);

}

# ==============================================================================
# Fonctions de lissage
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

		# On récupère les ids des sondes déjà présente
		my @ids_sondes = map {$_->{'probe_id'}} @sondes_lisses;

		# On fait l'union des sondes déjà présente et de celles de la
		# condition
		foreach my $sonde (@sondes_condition){

			# Si la sonde est pas la on l'ajoute
			if(!($sonde->{'probe_id'} ~~ @ids_sondes)){

				# On l'ajoute
				push(@sondes_lisses, $sonde);

			}

		}

	}

	return @sondes_lisses;

}

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

		my @sondes_lisses_tmp = ();

		# On récupère les ids des sondes présentes dans la condition
		my @ids_sondes = map {$_->{'probe_id'}} @sondes_condition;

		# On fait l'intersection des sondes déjà présentes et des sondes
		# de la condition
		foreach my $sonde (@sondes_lisses){

			if($sonde->{'probe_id'} ~~ @ids_sondes){

				push(@sondes_lisses_tmp, $sonde);

			}

		}

		@sondes_lisses = @sondes_lisses_tmp;

	}

	# On retourne la liste des sondes lisses
	return @sondes_lisses;

}

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
