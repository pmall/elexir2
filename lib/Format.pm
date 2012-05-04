package Format;
use strict;
use warnings;
use Exporter qw(import);

our @EXPORT = qw(get_base_fasterdb get_organism_adaptor get_table_sondes
	get_table_intensites get_table_dabg get_table_transcription get_table_ni
	get_table_si get_table_splicing get_table_carac_entites get_table_prom
	get_table_polya date traduction_type);

# ==============================================================================
# Formatage commun a tout les scripts
# ==============================================================================

sub get_base_fasterdb{

	my($organism) = @_;

	return ($organism eq 'human') ? 'fasterdb_humain' : 'fasterdb_souris';

}

sub get_organism_adaptor{

	my($organism) = @_;

	return ($organism eq 'human') ? 'Human' : 'Mouse';

}

sub get_table_sondes{

	my($organism) = @_;

	return ($organism eq 'human')
		? 'humain_probes_status'
		: 'souris_probes_status';

}

sub get_table_intensites{

	my($id_project) = @_;

	return '_' . $id_project . '_intensites';

}

sub get_table_dabg{

	my($id_project) = @_;

	return '_' . $id_project . '_dabg';

}

sub get_table_transcription{

	my($id_project, $id_analyse) = @_;

	return '_' . $id_project . '__' . $id_analyse . '_transcription';

}

sub get_table_ni{

	my($id_project, $id_analyse) = @_;

	return '_' . $id_project . '__' . $id_analyse . '_NIs';

}

sub get_table_si{

	my($id_project, $id_analyse) = @_;

	return '_' . $id_project . '__' . $id_analyse . '_SIs';

}

sub get_table_splicing{

	my($id_project, $id_analyse) = @_;

	return '_' . $id_project . '__' . $id_analyse . '_splicing';

}

sub get_table_carac_entites{

	my($organism) = @_;

	return ($organism eq 'human')
		? 'humain_carac_entites'
		: 'souris_carac_entites';

}

sub get_table_prom{

	my($organism) = @_;

	return ($organism eq 'human')
		? 'humain_prom'
		: 'souris_prom';

}

sub get_table_polya{

	my($organism) = @_;

	return ($organism eq 'human')
		? 'humain_polya'
		: 'souris_polya';

}

# ==============================================================================
# Fonctions de formattage
# ==============================================================================

sub date{

	my $time = time;

	my(
		$seconde,
		$minute,
		$heure,
		$jour,
		$mois,
		$annee,
		$jour_semaine,
		$jour_annee,
		$heure_hiver_ou_ete
	) = localtime($time);

	$mois  += 1; # Par défaut, le mois de janvier = 0
	$annee += 1900; # Par défaut, année 1900 = 0

	# Ajout d'un 0 si le chiffre est < 10
	foreach ( $seconde, $minute, $heure, $jour, $mois, $annee ) {
		s/^(\d)$/0$1/;
	}

	my @jours_semaine = (
		"lundi",
		"mardi",
		"mercredi",
		"jeudi",
		"vendredi",
		"samedi",
		"dimanche"
	);

	$jour_semaine = $jours_semaine[$jour_semaine - 1];

	my %h_date = (
		"date"         => "$jour-$mois-$annee",
		"heure"        => "$heure:$minute:$seconde",
		"jour_semaine" => $jour_semaine,
		"jour_annee"   => $jour_annee,
		"hiverOuEte"   => $heure_hiver_ou_ete,
	);
  
	my $string_date = "$h_date{jour_semaine} $h_date{date}, $h_date{heure}";

	return $string_date;

}

sub traduction_type{

	my($type) = @_;

	my %traduction = (
		'exon' => 'ASE',
		'prom' => 'AFE',
		'polya' => 'ALE',
		'intron-ret' => 'IR',
		'donor' => 'DON',
		'acceptor' => 'ACC',
		'deletion' => 'DEL',
		'3primeUTR' => '3\'UTR',
	);

	return $traduction{$type};

}

1;
