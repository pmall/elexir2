#!/usr/bin/perl
use strict;
use warnings;
use YAML::XS qw(LoadFile);
use DBI;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use FindBin qw($Bin);
use PDF::API2;
use PDF::Table;

# ==============================================================================
# Paramètres
# ==============================================================================

# On récupère l'identifiant du projet
my $id_project = shift @ARGV || die("Vous devez passer un identifiant de projet en paramètre");

# On récupère un hash de config
my $config = LoadFile($FindBin::Bin . '/config.yml');

# Algo a utiliser pour le qc
my $algo = $config->{'qc'}{'algo'};

# On défini le dossier contenant les puces
my $celdir = $config->{'dir_cel'};

# On défini les identifiants pour la bdd
my $db_host = $config->{'db_host'};
my $db_user = $config->{'db_user'};
my $db_pass = $config->{'db_pass'};
my $db_name = $config->{'db_name'};

# Script pour créer les images avec R
my $qc_script = $FindBin::Bin . '/qc.r';

# Fichier qui contient la doc
my $qc_doc = $FindBin::Bin . '/qc_doc';

# On défini le dossier de sortie
my $out_dir = $config->{'dir_qc'} . '/' . $id_project;

# On défini le chemin du pdf
my $pdf_file = $out_dir . '/report.pdf';

# On crée le dossier de sortie
make_path($out_dir);

# On défini un dossier temporaire
my $tmp_dir = tempdir(CLEANUP => 1);

# Pour supprimer le dossier temporaire lors de ctrl+C
$SIG{INT} = sub{ exit; };

# ==============================================================================
# Paramètres du fichier PDF
# ==============================================================================

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
	"SELECT dir, name, type, organism FROM projects WHERE id = ?"
);

my $select_chips_sth = $dbh->prepare(
	"SELECT name FROM chips WHERE id_project = ?"
);

# ==============================================================================
# On récupère les infos du projet
# ==============================================================================

# On selectionne les infos du projet
$select_project_sth->execute($id_project);

# on récupère les infos des projets
my($dir_project, $name_project, $type, $organism) = $select_project_sth->fetchrow_array;

# Si le projet n'est pas dans la bdd on die
die("Le projet $id_project n'est pas dans la bdd") if(!$dir_project);

# On selectionne les puces
$select_chips_sth->execute($id_project);

my @chips = @{$select_chips_sth->fetchall_arrayref({})};

# Si il n'y a pas de puces dans la bdd on die
die("Le projet $id_project correspond a aucune puce dans la bdd") if(@chips == 0);

# On récupère le nom de chaque puce
my @chips_names = (map { $_->{'name'} } @chips);

# On fait une liste des chemins des puces
my @chips_files = (map {
	$celdir . '/' . $dir_project . '/' . $_
} @chips_names);

# On crée la liste des fichier de puce pour la ligne de commande
my $chips_files_list = join(' ', @chips_files);

# On échappe les parenthèses des noms de puce
$chips_files_list =~ s/\(/\\(/g;
$chips_files_list =~ s/\)/\\)/g;

# On récupère les annotations
my $pgf = $config->{'annotations'}{$type}{$organism}{'pgf'};
my $clf = $config->{'annotations'}{$type}{$organism}{'clf'};
my $mps = $config->{'annotations'}{$type}{$organism}{'mps'};
my $qcc = $config->{'annotations'}{$type}{$organism}{'qcc'};

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

print `R --slave --args $tmp_dir $algo $img_width $img_height < $qc_script`;

print 'Fin création des images avec R ' . "\n";

# ==============================================================================
# Fonctions pour le pdf
# ==============================================================================

my $add_page = sub{

	my($pdf) = @_;

	my $page = $pdf->page;
	$page->mediabox($page_width, $page_height);

	return $page;

};

my $add_image = sub{

	my($pdf, $page, $file, $x, $y) = @_;

	my $image = $page->gfx;
	my $fichier_image = $pdf->image_png($file);
	$image->image($fichier_image, $x, $y, $img_width, $img_height);

};

# ==============================================================================
# On crée le PDF
# ==============================================================================

# On défini les coordonnées des objets
my $x		= (($page_width - $img_width)/2);
my $top_y	= $page_height - $img_height - (($page_height - ($img_height * 2))/4);
my $bot_y	= (($page_height - ($img_height * 2))/4);
my $center	= $page_width / 2;

# On crée le pdf
my $pdf = PDF::API2->new(-file => $pdf_file);

# On défini le titre du pdf
$pdf->info('Title' => 'QC Report ' . $name_project);

# On défini des fonts
my %font = (
	Helvetica => {
	Bold   => $pdf->corefont( 'Helvetica-Bold',    -encoding => 'latin1' ),
	Roman  => $pdf->corefont( 'Helvetica',         -encoding => 'latin1' ),
	Italic => $pdf->corefont( 'Helvetica-Oblique', -encoding => 'latin1' ),
	},
	Times => {
	Bold   => $pdf->corefont( 'Times-Bold',   -encoding => 'latin1' ),
	Roman  => $pdf->corefont( 'Times',        -encoding => 'latin1' ),
	Italic => $pdf->corefont( 'Times-Italic', -encoding => 'latin1' ),
	}
);

# Page de garde
my $page = $add_page->($pdf);

# Rectangle vert
my $blue_box = $page->gfx;
$blue_box->fillcolor('purple');
$blue_box->rect(0, 261/mm, $page_width, 36/mm);
$blue_box->fill;

# Header
my $header = $page->text;
$header->font($font{'Helvetica'}{'Bold'}, 48/pt);
$header->fillcolor('white');
$header->translate(1/mm, 261/mm + 36/pt);
$header->text('ELEXIR');

# subHeader
my $sub_header = $page->text;
$sub_header->font($font{'Helvetica'}{'Bold'}, 36/pt);
$sub_header->fillcolor('white');
$sub_header->translate($page_width, 261/mm);
$sub_header->text_right('Quality Control Report');

# Ligne noire
my $black_line = $page->gfx;
$black_line->strokecolor('black');
$black_line->move(0, 261/mm);
$black_line->line($page_width, 261/mm );
$black_line->stroke;

# EXP name
my $titre = $page->text;
$titre->font($font{'Helvetica'}{'Roman'}, 24/pt);
$titre->fillcolor('black');
$titre->translate($center, 251/mm - 12/pt);
$titre->text_center($name_project);

# On fait un tableau pour afficher les nom des fichiers cel
my $i = 0;
my @tab_rows = ();

foreach(@chips_names){

	push(@tab_rows, [++$i, $_]);

}

# Le tableau qui résume les puces
my $cel_table = new PDF::Table;

# On print le tableau
$cel_table->table(
	$pdf,
	$page,
	\@tab_rows,
	-x			=> $x,
	-w			=> $img_width,
	-start_y		=> 241/mm,
	-next_y			=> 287/mm,
	-start_h		=> 231/mm,
	-next_h			=> 277/mm,
	-padding		=> 2/mm,
	-font			=> $font{'Helvetica'}{'Roman'},
	-fontsize		=> 12/pt,
	-max_word_length	=> 20,
	-background_color_odd	=> 'white',
	-background_color_even	=> 'lightgrey',
	-new_page_func		=> sub{return $add_page->($pdf);}
);

# Première page de graph (pca + auc)
$page = $add_page->($pdf, $page_width, $page_height);
$add_image->($pdf, $page, $tmp_dir . '/pca.png', $x, $top_y);
$add_image->($pdf, $page, $tmp_dir . '/pos_vs_neg_auc.png', $x, $bot_y);

# Première page de graph (raw + mean)
$page = $add_page->($pdf, $page_width, $page_height);
$add_image->($pdf, $page, $tmp_dir . '/raw_intensities.png', $x, $top_y);
$add_image->($pdf, $page, $tmp_dir . '/all_probeset_mean.png', $x, $bot_y);

# Première page de graph (mad et rle + rle boxplot)
$page = $add_page->($pdf, $page_width, $page_height);
$add_image->($pdf, $page, $tmp_dir . '/all_probeset_mad_rle.png', $x, $top_y);
$add_image->($pdf, $page, $tmp_dir . '/all_probeset_rle_boxplot.png', $x, $bot_y);

# Première page de graph (mad residual mean + rle mean)
$page = $add_page->($pdf, $page_width, $page_height);
$add_image->($pdf, $page, $tmp_dir . '/mad_residual_mean_controle.png', $x, $top_y);
$add_image->($pdf, $page, $tmp_dir . '/rle_mean_controle.png', $x, $bot_y);

# Première page de graph (bac spikes 5')
$page = $add_page->($pdf, $page_width, $page_height);
$add_image->($pdf, $page, $tmp_dir . '/bac_spike_ordre_5_1.png', $x, $top_y);
$add_image->($pdf, $page, $tmp_dir . '/bac_spike_ordre_5_2.png', $x, $bot_y);

# Première page de graph (bac spikes 3')
$page = $add_page->($pdf, $page_width, $page_height);
$add_image->($pdf, $page, $tmp_dir . '/bac_spike_ordre_3_1.png', $x, $top_y);
$add_image->($pdf, $page, $tmp_dir . '/bac_spike_ordre_3_2.png', $x, $bot_y);

# Première page de graph (plya spike 5')
$page = $add_page->($pdf, $page_width, $page_height);
$add_image->($pdf, $page, $tmp_dir . '/polya_spike_ordre_5_1.png', $x, $top_y);
$add_image->($pdf, $page, $tmp_dir . '/polya_spike_ordre_5_2.png', $x, $bot_y);

# Première page de graph (plya spike M)
$page = $add_page->($pdf, $page_width, $page_height);
$add_image->($pdf, $page, $tmp_dir . '/polya_spike_ordre_M_1.png', $x, $top_y);
$add_image->($pdf, $page, $tmp_dir . '/polya_spike_ordre_M_2.png', $x, $bot_y);

# Première page de graph (plya spike 3')
$page = $add_page->($pdf, $page_width, $page_height);
$add_image->($pdf, $page, $tmp_dir . '/polya_spike_ordre_3_1.png', $x, $top_y);
$add_image->($pdf, $page, $tmp_dir . '/polya_spike_ordre_3_2.png', $x, $bot_y);

# On écrit la doc
open(DOC, $qc_doc);

my @doc_paragraphs = <DOC>;

close(DOC);

my $doc_table = new PDF::Table;

my $width_of_last_line;
my $ypos_of_last_line;
my $left_over_text = join('', @doc_paragraphs);

while(length($left_over_text) > 0){

	$page = $add_page->($pdf, $page_width, $page_height);
	my $doc = $page->text;
	$doc->font($font{'Times'}{'Roman'}, 12/pt, -encoding => "utf8");
	$doc->fillcolor('black');

	($width_of_last_line, $ypos_of_last_line, $left_over_text) = $doc_table->text_block(
		$doc,
		$left_over_text,
		-x	=> $x,
		-y	=> $page_height - $x,
		-w	=> $img_width,
		-h	=> $page_height - ($x * 2),
		-align	=> 'justify',
		-lead	=> 18/pt
	);

}

# On sauvegarde le pdf
$pdf->save;
