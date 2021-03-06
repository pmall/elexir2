package Format;
use strict;
use warnings;
use FindBin qw($Bin);
use lib $FindBin::Bin;
use Math;
use Exporter qw(import);

our @EXPORT = qw(get_table_intensites get_table_dabg
	get_table_transcription get_table_splicing
	get_table_ase_a_priori get_table_jonction
	format_fold date);

# ==============================================================================
# Formatage commun a tout les scripts
# ==============================================================================

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

sub get_table_splicing{

	my($id_project, $id_analyse) = @_;

	return '_' . $id_project . '__' . $id_analyse . '_splicing';

}

sub get_table_ase_a_priori{

	my($id_project, $id_analyse) = @_;

	return '_' . $id_project . '__' . $id_analyse . '_ase_apriori';

}

sub get_table_jonction{

	my($id_project, $id_analyse) = @_;

	return '_' . $id_project . '__' . $id_analyse . '_jonction';

}

# ==============================================================================
# Fonctions de formattage
# ==============================================================================

sub format_fold{

	my($fold) = @_;

	my $fold_base10 = ($fold >= 1) ? $fold : 1/$fold;

	return round($fold_base10, 2);

}

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

1;
