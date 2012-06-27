package Analyse;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Format;
use Math;
use Utils;
use Replicat;

# ==============================================================================
# Retourne les infos de l'analyse
# ==============================================================================

# => Factory : Tout le reste découle de la liste 'design'

sub get_analyse{

	my($class, $dbh, $id_analyse) = @_;

	# On selectionne les infos de l'analyse
	my $select_infos_analyse_sth = $dbh->prepare(
		"SELECT a.id, a.name, p.id AS id_project, p.type AS type_chips,
		a.version, p.organism, a.type, a.paired
		FROM analyses AS a, projects AS p
		WHERE a.id_project = p.id
		AND a.id = ?"
	);

	# On selectionne les infos de l'analyse
	$select_infos_analyse_sth->execute($id_analyse);
	my $infos_analyse = $select_infos_analyse_sth->fetchrow_hashref;
	$select_infos_analyse_sth->finish;

	# Si l'info analyse est undef on retourne undef
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

	# On défini les conditions de l'analyse et le numero max
	my $conditions = {};
	my $nb_max = 0;

	# On selectionne les puces
	$select_chips_sth->execute($infos_analyse->{'id'});

	# Pour chaque puces
	while(my($letter, $condition, $num) = $select_chips_sth->fetchrow_array){

		# On calcule le nb max
		$nb_max = $num if($num > $nb_max);

		# On défini le nom du sample
		my $sample = $condition . '_' . $num;

		# On ajoute au sample
		if(!$conditions->{$letter}){

			$conditions->{$letter} = [$sample];

		}else{

			push(@{$conditions->{$letter}}, $sample);

		}

	}

	# On calcule le nombre de paires de replicats
	$infos_analyse->{'nb_paires_rep'} = ($infos_analyse->{'paired'})
		? $nb_max
		: 1;

	# On défini le design de l'expérience
	my $paires = [];

	# Selon que l'analyse soit simple ou composée, ça change...
	if($infos_analyse->{'type'} eq 'simple'){

		# Pour chaque paire de replicat
		for(my $i = 0; $i < $infos_analyse->{'nb_paires_rep'}; $i++){

			$paires->[$i] = {
				'cont' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'A'}->[$i]])
					: new Replicat($conditions->{'A'}),
				'test' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'B'}->[$i]])
					: new Replicat($conditions->{'B'}) 
			};

		}

	}else{

		# Analyse de type composée, on récupère les sous comparaisons
		my $paires_cont = [];
		my $paires_test = [];

		# Pour chaque paire de replicat
		for(my $i = 0; $i < $infos_analyse->{'nb_paires_rep'}; $i++){

			$paires_cont->[$i] = {
				'cont' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'A'}->[$i]])
					: new Replicat($conditions->{'A'}),
				'test' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'B'}->[$i]])
					: new Replicat($conditions->{'B'})
			};

			$paires_test->[$i] = {
				'cont' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'C'}->[$i]])
					: new Replicat($conditions->{'C'}),
				'test' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'D'}->[$i]])
					: new Replicat($conditions->{'D'})
			};

		}

		# On fait les designs cont et test
		my $cont = {%{$infos_analyse}, 'design' => $paires_cont};
		my $test = {%{$infos_analyse}, 'design' => $paires_test};

		# On intègre les sous comparaisons à la comparaison globale
		$paires->[0] = {
			'cont' => new Analyse($cont),
			'test' => new Analyse($test)
		};

	}

	# La liste de paires est le design de l'analyse
	$infos_analyse->{'design'} = $paires;

	# On retourne un objet analyse
	return new Analyse($infos_analyse);

}

# ==============================================================================
# Constructeur
# ==============================================================================

sub new{

	my($class, $infos_analyse) = @_;

	$infos_analyse->{'select_dabg_sth'} = undef;
	$infos_analyse->{'select_intensites_sth'} = undef;

	bless($infos_analyse, $class);

	return $infos_analyse;

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
# Retourne la liste des sondes exprimées à partir d'une liste d'infos de sondes
# ==============================================================================

sub get_sondes_exprimees{

	my($this, $dbh, $ref_ids_sondes, $seuil_dabg) = @_;

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
		if($this->dabg($dabg, $seuil_dabg)){

			# On va chercher ses intensites
			$select_intensites_sth->execute($probe_id);
			my $sonde = $select_intensites_sth->fetchrow_hashref;
			$select_intensites_sth->finish;

			# Et on l'ajoute à la liste des sondes
			push(@sondes, $sonde);

		}

	}

	return @sondes;	

}

# ==============================================================================
# Retourne vrai si la sonde passe le seuil du dabg dans au moins la moitiée
# des puces d'au moins une condition
# ==============================================================================

sub dabg{

	my($this, $sonde, $seuil) = @_;

	# On calcule combien de reps controle et de rep tests sont exprimés
	my $nb_paires_rep = @{$this->{'design'}};
	my $nb_exp_cont = 0;
	my $nb_exp_test = 0;

	# Pour chaque paire de replicats
	foreach my $paire (@{$this->{'design'}}){

		# On calcule si la sonde est exprimée dans controle et
		# si elle est exprimé dans test
		$nb_exp_cont++ if($paire->{'cont'}->dabg($sonde, $seuil));
		$nb_exp_test++ if($paire->{'test'}->dabg($sonde, $seuil));

	}

	# Si exprimée dans la moitié des reps controle ou la moitié des
	# reps test, on retourne true
	return ($nb_exp_cont > ($nb_paires_rep/2) or $nb_exp_test > ($nb_paires_rep/2));

}

# ==============================================================================
# Retourne une liste de sondes lissées pour la transcription
# ==============================================================================

sub lissage{

	my($this, $ref_sondes, $ref_func_aggr) = @_;

	my @sondes_lisses_cont = @{$ref_sondes};
	my @sondes_lisses_test = @{$ref_sondes};

	foreach my $paire (@{$this->{'design'}}){

		my @sondes_lisses_cont_rep = $paire->{'cont'}->lissage(
			$ref_sondes,
			$ref_func_aggr
		);

		my @sondes_lisses_test_rep = $paire->{'test'}->lissage(
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
		my @fcs_cont = $paire->{'cont'}->fcs_sonde($sonde);
		my @fcs_test = $paire->{'test'}->fcs_sonde($sonde);

		# On fait tout les fcs de cette paire de replicat
		for(my $i = 0; $i < @fcs_cont; $i++){

			push(@fcs, $fcs_test[$i]/$fcs_cont[$i]);

		}

	}

	# On retourne les fcs de la sonde dans chaque paire de replicats
	return @fcs;

}

# ==============================================================================
# Retourne la liste des FCs de chaque sonde (liste de liste)
# ==============================================================================

sub fcs_sondes{

	my($this, $ref_sondes) = @_;

	my @fcs_sondes = ();

	foreach my $sonde (@{$ref_sondes}){

		my @fcs_sonde = $this->fcs_sonde($sonde);

		push(@fcs_sondes, \@fcs_sonde);

	}

	return @fcs_sondes;

}

# ==============================================================================
# Retourne le FC du groupe de sonde et sa p_value à partir des sondes
# ==============================================================================

sub fc_gene{

	my($this, $ref_sondes) = @_;

	my @fcs_sondes = $this->fcs_sondes($ref_sondes);

	return fc_matrix(\@fcs_sondes);

}

# ==============================================================================
# Retourne la liste des SIs d'une sonde (une par paire de replicat)
# ==============================================================================

sub sis_sonde{

	my($this, $fc_groupe, $sonde) = @_;

	my @SIs = ();

	my @fcs = $this->fcs_sonde($sonde);

	foreach(@fcs){ push(@SIs, ($_/$fc_groupe)) }

	return @SIs;

}

# ==============================================================================
# Retourne la liste des SIs de chaque sonde (liste de liste)
# ==============================================================================

sub sis_sondes{

	my($this, $fc_groupe, $ref_sondes) = @_;

	my @SIs_sondes = ();

	foreach my $sonde (@{$ref_sondes}){

		my @SIs_sonde = $this->sis_sonde($fc_groupe, $sonde);

		push(@SIs_sondes, \@SIs_sonde);

	}

	return @SIs_sondes;

}

# ==============================================================================
# Retourne le SI du groupe de sonde et sa p_value à partir des sondes
# ==============================================================================

sub si_entite{

	my($this, $fc_groupe, $ref_sondes) = @_;

	my @SIs_sondes = $this->sis_sondes($fc_groupe, $ref_sondes);

	return si_matrix(\@SIs_sondes, $this->{'paired'});

}

1;
