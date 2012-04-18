#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use File::Temp qw(tempdir);

# ==============================================================================
# Paramètres
# ==============================================================================

# Algo a utiliser pour le qc
# On fait une analyse rma
my $algo = 'rma';

# On défini le dossier contenant les puces
my $celdir = '/home/pierre/workspace/celdir';

# On défini les identifiants pour la bdd
my $db_host = 'localhost';
my $db_name = 'elexir2';
my $db_user = 'pierre';
my $db_pass = 'ysbag';

# Fichiers d'annotation
my $dir_annotation = '/home/pierre/workspace/annotations';

my $annotations = {
	'exon' => {
		'human' => {
			'clf' => $dir_annotation . '/HuEx-1_0-st-v2.r2/HuEx-1_0-st-v2.r2.clf',
			'pgf' => $dir_annotation . '/HuEx-1_0-st-v2.r2/HuEx-1_0-st-v2.r2.pgf',
			'mps' => $dir_annotation . '/HuEx-1_0-st-v2.r2.dt1.hg18.ps/HuEx-1_0-st-v2.r2.dt1.hg18.core.mps',
			'qcc' => $dir_annotation . '/HuEx-1_0-st-v2.r2/HuEx-1_0-st-v2.r2.qcc'
		},
		'mouse' => {
			'clf' => $dir_annotation . '/MoEx-1_0-st-v1.r2/MoEx-1_0-st-v1.r2.clf',
			'pgf' => $dir_annotation . '/MoEx-1_0-st-v1.r2/MoEx-1_0-st-v1.r2.pgf',
			'mps' => $dir_annotation . '/MoEx-1_0-st-v1.r2.dt1.mm9.ps/MoEx-1_0-st-v1.r2.dt1.mm9.core.mps',
			'qcc' => $dir_annotation . '/MoEx-1_0-st-v1.r2/MoEx-1_0-st-v1.r2.qcc'
		}
	},
	'ggh' => {
		'human' => {
			'clf' => $dir_annotation . '/hGlue_3_0_v1.R-JETTA_lib_annot_files/hGlue_3_0_v1.clf',
			'pgf' => $dir_annotation . '/hGlue_3_0_v1.R-JETTA_lib_annot_files/hGlue_3_0_v1.pgf',
			'mps' => $dir_annotation . '/hGlue_3_0_v1.R-JETTA_lib_annot_files/hGlue_3_0_v1.TC.mps',
			'qcc' => $dir_annotation . '/hGlue_3_0_v1.R-JETTA_lib_annot_files/hGlue_3_0_v1.qcc'
		}
	}
};

# On récupère l'identifiant du projet
my $id_project = shift @ARGV || die("Vous devez passer un identifiant de projet en paramètre");

# Pour supprimer le dossier temporaire lors de ctrl+C
$SIG{INT} = sub{ exit; };

# On défini un dossier temporaire
#my $tmp_dir = tempdir(CLEANUP => 1);
my $tmp_dir = './tmp';

# Milimètres
use constant mm => 25.4 / 72;
use constant pt => 1;

# Taille des images
my $img_width	= int(145/mm);
my $img_height	= int(145/mm);
my $page_width	= 210/mm;
my $page_height	= 297/mm;

# ==============================================================================
# Préparation des requètes
# ==============================================================================

# On se connecte à la bdd et on prépare les requetes
my $dbh = DBI->connect(
	'DBI:mysql:' . $db_name . ':' . $db_host,
	$db_user,
	$db_pass
);

my $select_project_sth = $dbh->prepare(
	"SELECT dir, type, organism FROM _projects WHERE id = ?"
);

my $select_chips_sth = $dbh->prepare(
	"SELECT name, `condition`, num FROM _chips WHERE id_project = ?"
);

# ==============================================================================
# On récupère les infos du projet
# ==============================================================================

# On selectionne les infos du projet
$select_project_sth->execute($id_project);

# on récupère les infos des projets
my($dir_project, $type, $organism) = $select_project_sth->fetchrow_array;

# Si le projet n'est pas dans la bdd on die
die("Le projet $id_project n'est pas dans la bdd") if(!$dir_project);

# On selectionne les puces
$select_chips_sth->execute($id_project);

my @chips = @{$select_chips_sth->fetchall_arrayref({})};

# Si il n'y a pas de puces dans la bdd on die
die("Le projet $id_project correspond a aucune puce dans la bdd") if(@chips == 0);

# On fait une liste des chemins des puces
my @chips_files = (map {
	$celdir . '/' . $dir_project . '/' . $_->{name}
} @chips);

my $chips_files_list = join(' ', @chips_files);

# On récupère les annotations
my $annot_hash = $annotations->{$type}->{$organism};
my $pgf = $annot_hash->{'pgf'};
my $clf = $annot_hash->{'clf'};
my $mps = $annot_hash->{'mps'};
my $qcc = $annot_hash->{'qcc'};

# ==============================================================================
# On lance le traitement avec affymetrix power tools
# ==============================================================================

print 'Début du traitement avec affymetrix power tools ' . "\n";

# Traitement sur les puces avec affymetrix power tools
`apt-probeset-summarize -a $algo -c $clf -p $pgf -m $mps -qc-probesets $qcc -o $tmp_dir $chips_files_list`;

print 'Fin du traitement avec affymetrix power tools ' . "\n";

# ==============================================================================
# On crée les images avec R
# ==============================================================================

print 'Début création des images avec R ' . "\n";

`R --slave --args $tmp_dir $algo $img_width $img_height < qc.r`;

print 'Fin création des images avec R ' . "\n";
