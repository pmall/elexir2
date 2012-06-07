package Analyse;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Design;
use Math;
use Exporter qw(import);

our @EXPORT = qw(get_infos_analyse get_design dabg lissage_transcription
	lissage_epissage expression fcs_sondes fcs_sonde sis_sonde);

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
	$infos_analyse->{'design'} = get_design(
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

	# On défini le nom des condition
	my %letter2type = ('A' => 'control', 'B' => 'test');
	my @exp = ();

	$select_chips_sth->execute($id_analyse);

	while(my($letter, $condition, $num) = $select_chips_sth->fetchrow_array){

		my $type = $letter2type{$letter};

		if($type_analyse eq 'paire'){

			if(!$exp[$num - 1]){

				$exp[$num - 1] = { $type => [$condition . '_' . $num] };

			}else{

				$exp[$num - 1]->{$type} = [$condition . '_' . $num];

			}

		}else{

			if(!$exp[0]){

				$exp[0] = { 'control' => [], 'test' => [] };

			}

			push(@{$exp[0]->{$type}}, $condition . '_' . $num);

		}

	}

	return new Design(\@exp);

}

# ==============================================================================
# Calcul de l'expression d'une sonde a partir du dabg
# ==============================================================================

# Retourne 1 si la sonde est exprimée dans au moins la moitié des replicats
# d'au moins une condition, 0 sinon
sub dabg{

	my($seuil, $ref_exp, $sonde) = @_;

	my @exp = @{$ref_exp};
	my $nb_control = 0;
	my $nb_test = 0;
	my $nb_exp_control = 0;
	my $nb_exp_test = 0;

	foreach my $paire (@exp){

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

	my($ref_exp, $ref_sondes) = @_;

	my @exp = @{$ref_exp};
	my @sondes = @{$ref_sondes};

	# On défini la liste des sondes à utiliser pour la transcription
	my @sondes_lisses = ();

	# On récupère les samples des deux conditions
	my %conditions = ('control' => [], 'test' => []);

	foreach my $paire (@exp){

		push(@{$conditions{'control'}}, @{$paire->{'control'}});
		push(@{$conditions{'test'}}, @{$paire->{'test'}});

	}

	# Pour chaque conditions
	foreach my $condition (keys %conditions){

		# On part du principe que toutes les sondes sont gardé dans la
		# condition et on va les éliminer
		my @sondes_cond = @sondes;

		# Pour chaque replicat de la condition
		foreach my $sample (@{$conditions{$condition}}){

			# On récupère les sondes du sample
			my @sondes_rep = map { $_->{$sample} } @sondes;

			# On calcule la médiane et l'écart type
			my $mean = mean(@sondes_rep);
			my $sd = sd(@sondes_rep);

			# On garde seulement les sondes dont la valeur est comprise
			# dans la moyenne +/- l'écart type
			# Ca en élimine un certain nombre de sondes, replicat
			# après réplicat
			@sondes_cond = grep {
				abs($_->{$sample} - $mean) <= $sd
			} @sondes_cond;

		}

		# Union des listes de sondes des conditions
		# On ajoute les sondes gardés pour la condition à la liste des
		# sondes lissées en évitant les doublons
		foreach my $sonde_cond (@sondes_cond){

			# On récupère les ids des sondes déjà là
			my @probes_ids = map {$_->{'probe_id'}} @sondes_lisses;

			# Si la sonde n'est pas déjà dans la liste
			if(!($sonde_cond->{'probe_id'} ~~ @probes_ids)){

				# On l'ajoute
				push(@sondes_lisses, $sonde_cond);

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

	my($ref_design, $ref_sondes) = @_;

	my @sondes = @{$ref_sondes};

	# On défini la liste des sondes à utiliser pour l'épissage
	my @sondes_lisses = @sondes;

	# Pour chaque paires
	foreach my $paire (@{$ref_design}){

		@sondes_lisses = lissage_replicat($paire->{'control'}, @sondes);
		@sondes_lisses = lissage_replicat($paire->{'test'}, @sondes);

	}

	return @sondes_lisses;

}

# ==============================================================================
# Retourne les sondes lissées sur un replicat
# ==============================================================================

sub lissage_replicat{

	my($ref_design, @sondes) = @_;

	my @sondes_lisses = @sondes;

	if(ref($ref_design) eq 'Design'){

		@sondes_lisses = lissage_epissage($ref_design, \@sondes);

	}else{

		foreach my $sample (@{$ref_design}){

			my @valeurs_sample = map { $_->{$sample} } @sondes;

			my $mean = mean(@valeurs_sample);
			my $sd = sd(@valeurs_sample);

			# On garde seulement les sondes comprise dans la moyenne
			# + / - la sd
			@sondes_lisses = grep {
				abs($_->{$sample} - $mean) <= $sd
			} @sondes_lisses;

		}

	}

	return @sondes_lisses;

}

# ==============================================================================
# Calcul de l'expression d'une liste de sonde
# ==============================================================================

# Retourne les valeurs d'expression d'un groupe de sonde
# (mediane de tout les samples d'un réplicat puis médiane de ces valeurs
# => une valeur par replicat)
sub expression{

	my($ref_design, $ref_sondes) = @_;

	my @design = @{$ref_design};
	my @sondes = @{$ref_sondes};

	my @expressions = ();

	foreach my $paire (@design){

		push(@expressions, expression_replicat($paire->{'control'}, @sondes));
		push(@expressions, expression_replicat($paire->{'test'}, @sondes));

	}

	return @expressions;

}

# ==============================================================================
# Retourne les valeurs d'expression d'un replicat
# ==============================================================================

sub expression_replicat{

	my($ref_design, @sondes) = @_;

	my @expressions = ();

	if(ref($ref_design) eq 'Design'){

		push(@expressions, expression($ref_design, \@sondes));

	}else{

		my @medians = ();

		foreach my $sonde (@sondes){

			push(@medians, map { $sonde->{$_} } @{$ref_design});

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

	my @sondes = @{$ref_sondes};

	my @fcs = ();

	foreach my $sonde (@sondes){

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

	my @design = @{$ref_design};

	my @fcs_replicats = ();

	# Un compteur pour toutes les paires
	foreach my $paire (@design){

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
# Fonctions pour le si
# ==============================================================================

sub sis_sonde{

	my($ref_exp, $fc, $sonde) = @_;

	my @SIs = ();

	# On calcule les SIs
	# pour ça il faut récupérer les folds déjà
	my @fcs = fcs_sonde($ref_exp, $sonde);

	# Si de la sonde (cad, fc de la sonde sur fc du groupe)
	foreach(@fcs){ push(@SIs, ($_/$fc)) }

	return @SIs;

}

1;
