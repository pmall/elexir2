package Analyse;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Format;
use Math;
use Stats;
use Utils;
use Replicat;

# ==============================================================================
# Retourne les infos de l'analyse
# ==============================================================================

# => Factory : Tout le reste découle de la liste 'design'
# Un peu fait à l'arrache.

sub get_analyse{

	my($class, $dbh, $id_analyse) = @_;

	# On selectionne les infos de l'analyse
	my $select_analyse_sth = $dbh->prepare(
		"SELECT a.id, a.name, p.id AS id_project, p.type AS type_chips,
		a.version, p.organism, a.type, a.paired
		FROM analyses AS a, projects AS p
		WHERE a.id_project = p.id
		AND a.id = ?"
	);

	# On selectionne les infos de l'analyse
	$select_analyse_sth->execute($id_analyse);
	my $analyse = $select_analyse_sth->fetchrow_hashref;
	$select_analyse_sth->finish;

	# Si l'info analyse est undef on retourne undef
	return undef if(!$analyse);

	# On selectionne les puces de l'analyse
	my $select_chips_sth = $dbh->prepare(
		"SELECT c.name, g.letter, c.condition, c.num
		FROM analyses AS a, chips AS c, groups AS g
		WHERE a.id_project = c.id_project
		AND a.id = g.id_analysis
		AND c.condition = g.condition
		AND a.id = ?
		ORDER BY num ASC"
	);

	# On défini les conditions de l'analyse et le numero max
	my $conditions = {};
	my $chip_desc = {};
	my $nb_max = 0;

	# On selectionne les puces
	$select_chips_sth->execute($analyse->{'id'});

	# Pour chaque puces
	while(my($name, $letter, $condition, $num) = $select_chips_sth->fetchrow_array){

		# On calcule le nb max
		$nb_max = $num if($num > $nb_max);

		# On défini le nom du sample
		my $sample = $condition . '_' . $num;

		# On ajoute au sample
		if(!$conditions->{$letter}){

			$conditions->{$letter} = [$sample];
			$chip_desc->{$letter} = [{'sample' => $sample, 'name' => $name}];

		}else{

			push(@{$conditions->{$letter}}, $sample);
			push(@{$chip_desc->{$letter}}, {'sample' => $sample, 'name' => $name});

		}

	}

	# On garde les hashes conditions et chipnames
	$analyse->{'chip_desc'} = $chip_desc;

	# On calcule le nombre de paires de replicats
	$analyse->{'nb_paires_rep'} = ($analyse->{'paired'})
		? $nb_max
		: 1;

	# On défini le design de l'expérience
	my $paires = [];

	# Selon que l'analyse soit simple ou composée, ça change...
	my @types_simples = ('simple', 'jonction', 'apriori');

	if($analyse->{'type'} ~~ @types_simples){

		# Pour chaque paire de replicat
		for(my $i = 0; $i < $analyse->{'nb_paires_rep'}; $i++){

			$paires->[$i] = {
				'cont' => ($analyse->{'paired'})
					? new Replicat([$conditions->{'A'}->[$i]])
					: new Replicat($conditions->{'A'}),
				'test' => ($analyse->{'paired'})
					? new Replicat([$conditions->{'B'}->[$i]])
					: new Replicat($conditions->{'B'}) 
			};

		}

	}else{

		# Analyse de type composée, on récupère les sous comparaisons
		my $paires_cont = [];
		my $paires_test = [];

		# Pour chaque paire de replicat
		for(my $i = 0; $i < $analyse->{'nb_paires_rep'}; $i++){

			$paires_cont->[$i] = {
				'cont' => ($analyse->{'paired'})
					? new Replicat([$conditions->{'A'}->[$i]])
					: new Replicat($conditions->{'A'}),
				'test' => ($analyse->{'paired'})
					? new Replicat([$conditions->{'B'}->[$i]])
					: new Replicat($conditions->{'B'})
			};

			$paires_test->[$i] = {
				'cont' => ($analyse->{'paired'})
					? new Replicat([$conditions->{'C'}->[$i]])
					: new Replicat($conditions->{'C'}),
				'test' => ($analyse->{'paired'})
					? new Replicat([$conditions->{'D'}->[$i]])
					: new Replicat($conditions->{'D'})
			};

		}

		# On fait les designs cont et test
		my $cont = {%{$analyse}, 'design' => $paires_cont};
		my $test = {%{$analyse}, 'design' => $paires_test};

		# On intègre les sous comparaisons à la comparaison globale
		$paires->[0] = {
			'cont' => new Analyse($cont),
			'test' => new Analyse($test)
		};

	}

	# La liste de paires est le design de l'analyse
	$analyse->{'design'} = $paires;

	# On retourne un objet analyse
	return new Analyse($analyse);

}

# ==============================================================================
# Constructeur
# ==============================================================================

sub new{

	my($class, $analyse) = @_;

	$analyse->{'select_dabg_sth'} = undef;
	$analyse->{'select_intensites_sth'} = undef;

	bless($analyse, $class);

	return $analyse;

}

# ==============================================================================
# Retourne la requete préparée pour selectionner les valeurs de dabg d'une sonde
# ==============================================================================

sub get_select_dabg{

	my($this, $dbh) = @_;

	$this->{'select_dabg_sth'} //= $dbh->prepare( # /
		"SELECT *
		FROM " . get_table_dabg($this->{'id_project'}) . "
		WHERE probe_id = ?"
	);

	return $this->{'select_dabg_sth'};

}

# ==============================================================================
# Retourne la requete préparée pour selectionner les intensités d'une sonde
# ==============================================================================

sub get_select_intensites{

	my($this, $dbh) = @_;

	$this->{'select_intensites_sth'} //= $dbh->prepare( # /
		"SELECT *
		FROM " . get_table_intensites($this->{'id_project'}) . "
		WHERE probe_id = ?"
	);

	return $this->{'select_intensites_sth'};

}

# ==============================================================================
# Fonction générale pour récupérer les sondes exprimées
# ==============================================================================

sub get_sondes_exprimees{

	my($this, $dbh, $ref_ids_sondes, $seuil, $group, $both) = @_;

	# Si il y a pas de sonde on retourne une matrice vide
	return [] if(@{$ref_ids_sondes} == 0);

	if($group){

		return $this->get_sondes_exprimees_groupe(
			$dbh, $ref_ids_sondes, $seuil, $both
		);

	}else{

		return $this->get_sondes_exprimees_simple(
			$dbh, $ref_ids_sondes, $seuil, $both
		);

	}

}

# ==============================================================================
# Retourne la matrice des intensités des sondes exprimées à partir d'une liste
# d'identifiants de sondes
# ==============================================================================

sub get_sondes_exprimees_simple{

	my($this, $dbh, $ref_ids_sondes, $seuil, $both) = @_;

	# On récupère les requetes préparées si elles le sont pas déjà dans
	# le cache
	my $select_dabg_sth = $this->get_select_dabg($dbh);
	my $select_intensites_sth = $this->get_select_intensites($dbh);

	# On initialise la liste des sondes exprimées
	my @sondes = ();

	foreach my $probe_id (@{$ref_ids_sondes}){

		# On récupère les valeurs de dabg de la sonde
		$select_dabg_sth->execute($probe_id);
		my $dabg = $select_dabg_sth->fetchrow_hashref;
		$select_dabg_sth->finish;

		# Si la sonde est exprimée
		if($this->dabg_sonde($dabg, $seuil, $both)){

			# On va chercher ses intensites
			$select_intensites_sth->execute($probe_id);
			my $sonde = $select_intensites_sth->fetchrow_hashref;
			$select_intensites_sth->finish;

			# Et on l'ajoute à la liste des sondes
			push(@sondes, $sonde);

		}

	}

	return \@sondes;

}

# ==============================================================================
# Retourne la matrice des intensités des sondes exprimées à partir d'une liste
# d'identifiants de sonde en les traitant globalement.
# Cad si on passe la liste des sondes d'une entité :
# => matrice des intensités de toutes les sondes si l'entité est exprimée
# => matrice vide si elle n'est pas exprimée
# ==============================================================================

sub get_sondes_exprimees_groupe{

	my($this, $dbh, $ref_ids_sondes, $seuil, $both) = @_;

	# On récupère les requetes préparées si elles le sont pas déjà dans
	# le cache
	my $select_dabg_sth = $this->get_select_dabg($dbh);
	my $select_intensites_sth = $this->get_select_intensites($dbh);

	# On récupère tous les dabg des sondes
	my @liste_dabg = ();

	foreach my $probe_id (@{$ref_ids_sondes}){

		$select_dabg_sth->execute($probe_id);
		my $dabg = $select_dabg_sth->fetchrow_hashref;
		$select_dabg_sth->finish;

		push(@liste_dabg, $dabg);

	}

	# Si les sondes ne sont pas globalement exprimées on retourne une liste
	# vide
	return [] if(!$this->dabg_groupe(\@liste_dabg, $seuil, $both));

	# Sinon on récupère et retourne toutes les intensités
	my @sondes = ();

	foreach my $probe_id (@{$ref_ids_sondes}){

		$select_intensites_sth->execute($probe_id);
		my $sonde = $select_intensites_sth->fetchrow_hashref;
		$select_intensites_sth->finish;

		push(@sondes, $sonde);

	}

	return \@sondes;

}

# ==============================================================================
# Fonction dabg synonyme/raccourcit/compatibilité pour dabg_sonde
# ==============================================================================

sub dabg{

	my($this, $sonde, $seuil, $both) = @_;

	return $this->dabg_sonde($sonde, $seuil, $both);

}

# ==============================================================================
# Retourne vrai si la sonde passe le seuil du dabg dans au moins la moitiée
# des puces d'au moins une condition
# ==============================================================================

sub dabg_sonde{

	my($this, $sonde, $seuil, $both) = @_;

	# On calcule combien de reps controle et de rep tests sont exprimés
	my $nb_paires_rep = @{$this->{'design'}};
	my $nb_exp_cont = 0;
	my $nb_exp_test = 0;

	# Pour chaque paire de replicats
	foreach my $paire (@{$this->{'design'}}){

		# On calcule si la sonde est exprimée dans controle et
		# si elle est exprimé dans test
		$nb_exp_cont++ if($paire->{'cont'}->dabg_sonde($sonde, $seuil, $both));
		$nb_exp_test++ if($paire->{'test'}->dabg_sonde($sonde, $seuil, $both));

	}

	# Si exprimée dans la moitié des reps controle ou/et la moitié des
	# reps test, on retourne true
	if($both){

		return ($nb_exp_cont > ($nb_paires_rep/2) and $nb_exp_test > ($nb_paires_rep/2));

	}else{

		return ($nb_exp_cont > ($nb_paires_rep/2) or $nb_exp_test > ($nb_paires_rep/2));

	}

}

# ==============================================================================
# Retourne vrai si le groupe de sonde passe le seuil du dabg dans au moins la
# moitié des puces d'au moins une condition
# ==============================================================================

sub dabg_groupe{

	my($this, $ref_sondes, $seuil, $both) = @_;

	# On calcule combien de reps controle et de rep tests sont exprimés
	my $nb_paires_rep = @{$this->{'design'}};
	my $nb_exp_cont = 0;
	my $nb_exp_test = 0;

	# Pour chaque paire de replicats
	foreach my $paire (@{$this->{'design'}}){

		# On calcule si la sonde est exprimée dans controle et
		# si elle est exprimé dans test
		$nb_exp_cont++ if($paire->{'cont'}->dabg_groupe($ref_sondes, $seuil, $both));
		$nb_exp_test++ if($paire->{'test'}->dabg_groupe($ref_sondes, $seuil, $both));

	}

	# Si exprimée dans la moitié des reps controle ou/et la moitié des
	# reps test, on retourne true
	if($both){

		return ($nb_exp_cont > ($nb_paires_rep/2) and $nb_exp_test > ($nb_paires_rep/2));

	}else{

		return ($nb_exp_cont > ($nb_paires_rep/2) or $nb_exp_test > ($nb_paires_rep/2));

	}

}

# ==============================================================================
# Retourne une liste de sondes lissées pour la transcription
# ==============================================================================

sub lissage{

	my($this, $ref_sondes, $ref_func_aggr) = @_;

	my @sondes_lisses_cont = @{$ref_sondes};
	my @sondes_lisses_test = @{$ref_sondes};

	foreach my $paire (@{$this->{'design'}}){

		my $sondes_lisses_cont_rep = $paire->{'cont'}->lissage(
			$ref_sondes,
			$ref_func_aggr
		);

		my $sondes_lisses_test_rep = $paire->{'test'}->lissage(
			$ref_sondes,
			$ref_func_aggr
		);

		@sondes_lisses_cont = inter(
			\@sondes_lisses_cont,
			$sondes_lisses_cont_rep
		);

		@sondes_lisses_test = inter(
			\@sondes_lisses_test,
			$sondes_lisses_test_rep
		);

	}

	my @aggr = $ref_func_aggr->(
		\@sondes_lisses_cont,
		\@sondes_lisses_test
	);

	return \@aggr;

}

# ==============================================================================
# Lissage pour la transcription et pour l'épissage
# ==============================================================================

sub lissage_transcription{

	my($this, $ref_sondes) = @_;

	return $this->lissage($ref_sondes, \&union);

}

sub lissage_epissage{

	my($this, $ref_sondes) = @_;

	return $this->lissage($ref_sondes, \&inter);

}

# ==============================================================================
# Calcul de l'expression d'une liste de sonde
# ==============================================================================

# Retourne les valeurs d'expression d'un groupe de sonde
# (mediane de tout les samples d'un réplicat puis médiane de ces valeurs
# => une valeur par replicat)
sub expressions{

	my($this, $ref_sondes) = @_;

	my @expressions = ();

	foreach my $paire (@{$this->{'design'}}){

		push(@expressions, $paire->{'cont'}->expressions($ref_sondes));
		push(@expressions, $paire->{'test'}->expressions($ref_sondes));

	}

	return @expressions;

}

# ==============================================================================
# Retourne tous les fcs d'une sonde, un par paire de replicat
# ==============================================================================

sub fcs_sonde{

	my($this, $sonde) = @_;

	# On initialise la liste des fcs de la sonde
	my @fcs = ();

	# Pour chaque paire de replicats
	foreach my $paire (@{$this->{'design'}}){

		# On calcule la valeur de la sonde pour control et test
		my $ref_fcs_cont = $paire->{'cont'}->fcs_sonde($sonde);
		my $ref_fcs_test = $paire->{'test'}->fcs_sonde($sonde);

		# On fait tout les fcs de cette paire de replicat
		for(my $i = 0; $i < @{$ref_fcs_cont}; $i++){

			push(@fcs, $ref_fcs_test->[$i]/$ref_fcs_cont->[$i]);

		}

	}

	# On retourne les fcs de la sonde dans chaque paire de replicats
	return \@fcs;

}

# ==============================================================================
# Retourne la liste des FCs de chaque sonde (matrice)
# ==============================================================================

sub fcs_sondes{

	my($this, $ref_sondes) = @_;

	my @fcs_sondes = ();

	foreach my $sonde (@{$ref_sondes}){

		my $ref_fcs_sonde = $this->fcs_sonde($sonde);

		push(@fcs_sondes, $ref_fcs_sonde);

	}

	return \@fcs_sondes;

}

# ==============================================================================
# Retourne le FC du groupe de sonde et sa p_value à partir des sondes
# ==============================================================================

sub fc_gene{

	my($this, $ref_fcs_sondes) = @_;

	# On somme les fc des sondes sans effet replicat
	my($fc, @fcs_a_tester) = sum_no_rep_effect($ref_fcs_sondes);

	# On fait le test stat
	my $p_value = ttest([log2(@fcs_a_tester)], (log2($fc) >= 0));

	return ($fc, $p_value, @fcs_a_tester);

}

# ==============================================================================
# Retourne la liste des SIs d'une sonde (une par paire de replicat)
# ==============================================================================

sub sis_sonde{

	my($this, $ref_fcs_groupe, $ref_fcs_sonde) = @_;

	my @SIs = ();

	for(my $i = 0; $i < @{$ref_fcs_sonde}; $i++){

		push(@SIs, ($ref_fcs_sonde->[$i]/$ref_fcs_groupe->[$i]))

	}

	return \@SIs;

}

# ==============================================================================
# Retourne la liste des SIs de chaque sonde (liste de liste)
# ==============================================================================

sub sis_sondes{

	my($this, $ref_fcs_groupe, $ref_fcs_sondes) = @_;

	my @SIs_sondes = ();

	foreach my $ref_fcs_sonde (@{$ref_fcs_sondes}){

		my $ref_SIs_sonde = $this->sis_sonde(
			$ref_fcs_groupe,
			$ref_fcs_sonde
		);

		push(@SIs_sondes, $ref_SIs_sonde);

	}

	return \@SIs_sondes;

}

# ==============================================================================
# Retourne le SI du groupe de sonde et sa p_value à partir des sondes
# ==============================================================================

sub si_entite{

	my($this, $ref_SIs) = @_;

	my $SI;
	my @SIs_a_tester = ();

	if($this->{'paired'}){

		($SI, @SIs_a_tester) = sum_rep_effect($ref_SIs);

	}else{

		($SI, @SIs_a_tester) = sum_no_rep_effect($ref_SIs);

	}

	my $p_value = ttest([log2(@SIs_a_tester)], (log2($SI) >= 0));

	return($SI, $p_value, @SIs_a_tester);

}

1;
