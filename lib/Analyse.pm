package Analyse;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Replicat;
use Math;
use Utils;

# ==============================================================================
# Retourne les infos de l'analyse
# ==============================================================================

sub get_infos_analyse{

	my($class, $dbh, $id_analyse) = @_;

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

	$infos_analyse->{'conditions'} = $conditions;
	$infos_analyse->{'nb_paires_rep'} = ($infos_analyse->{'paired'})
		? $nb_max
		: 1;

	# On retourne les infos de l'analyse
	return $infos_analyse;

}

# ==============================================================================
# Retourne la description de l'analyse
# ==============================================================================

sub get_analyse{

	my($class, $dbh, $infos_analyse) = @_;

	my $conditions = $infos_analyse->{'conditions'};

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
		my $control = [];
		my $test = [];

		# Pour chaque paire de replicat
		for(my $i = 0; $i < $infos_analyse->{'nb_paires_rep'}; $i++){

			$control->[$i] = {
				'cont' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'A'}->[$i]])
					: new Replicat($conditions->{'A'}),
				'test' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'B'}->[$i]])
					: new Replicat($conditions->{'B'})
			};

			$test->[$i] = {
				'cont' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'C'}->[$i]])
					: new Replicat($conditions->{'C'}),
				'test' => ($infos_analyse->{'paired'})
					? new Replicat([$conditions->{'D'}->[$i]])
					: new Replicat($conditions->{'D'})
			};

		}

		# On intègre les sous comparaisons à la comparaison globale
		$paires->[0] = {
			'cont' => new Analyse($control),
			'test' => new Analyse($test)
		};

	}

	return new Analyse($paires);

}

# ==============================================================================
# Constructeur
# ==============================================================================

sub new{

	my($class, $ref_paires) = @_;

	bless($ref_paires, $class);

	return $ref_paires;

}

# ==============================================================================
# Retourne vrai si la sonde passe le seuil du dabg dans au moins la moitiée
# des puces d'au moins une condition
# ==============================================================================

sub dabg{

	my($this, $sonde, $seuil) = @_;

	# On calcule combien de reps controle et de rep tests sont exprimés
	my $nb_reps = @{$this};
	my $nb_exp_cont = 0;
	my $nb_exp_test = 0;

	# Pour chaque paire de replicats
	foreach my $paire (@{$this}){

		# On calcule si la sonde est exprimée dans controle et
		# si elle est exprimé dans test
		$nb_exp_cont++ if($paire->{'cont'}->dabg($sonde, $seuil));
		$nb_exp_test++ if($paire->{'test'}->dabg($sonde, $seuil));

	}

	# Si exprimée dans la moitié des reps controle ou la moitié des
	# reps test, on retourne true
	return ($nb_exp_cont > ($nb_reps/2) or $nb_exp_test > ($nb_reps/2));

}

# ==============================================================================
# Retourne une liste de sondes lissées pour la transcription
# ==============================================================================

sub lissage{

	my($this, $ref_sondes, $ref_func_aggr) = @_;

	my @sondes_lisses_cont = @{$ref_sondes};
	my @sondes_lisses_test = @{$ref_sondes};

	foreach my $paire (@{$this}){

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

	foreach my $paire (@{$this}){

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
	foreach my $paire (@{$this}){

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

	my($this, $fc_groupe, $ref_sondes, $paired) = @_;

	my @SIs_sondes = $this->sis_sondes($fc_groupe, $ref_sondes);

	return si_matrix(\@SIs_sondes, $paired);

}

1;
