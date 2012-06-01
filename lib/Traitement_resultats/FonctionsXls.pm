=head1 NAME

 FonctionsXls.pm - Fonctions pour la production des fichiers excels.

=head1 SYNOPSIS

 use RequetesXls;
 &RequetesXls::ecriture($tab_data, $feuille, $ligne, $format, $num_col);

=head1 DESCRIPTION

 Fonctions nécessaires à la production des fichiers excel.
 Regroupe des fonctions de mise en page, sélection dans mysql...
 
=cut

=head1 DEPENDANCES

=over

=item Traitement_resultats::ResumeAnalyse.pm

=back

=cut

package FonctionsXls;
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$FindBin::Bin/..";
use Math qw(round);
use Traitement_resultats::ResumeAnalyse;

# ---------------------------------------------------------------- #
#                           Mise en page                           #
# ---------------------------------------------------------------- #

=head1 FUNCTION ecriture

 Ecriture dans un fichier excel.

=cut

sub ecriture {
    my($tab_data, $feuille, $ligne, $format, $num_col) = @_;
    
    ( !$num_col ) ? $num_col = -1 : $num_col--;
    
    foreach my $data_cellule (@$tab_data){
        $num_col++;

        # Lien url misea
        if ( $data_cellule =~ /^.*http.*elexir.*$/i ) {
            $feuille->write_url($ligne, $num_col, $data_cellule, 'ELEXIR', $format);

        # Data
        }else{
            $feuille->write($ligne, $num_col, $data_cellule, $format);
        }
        
    }
    
}


# ---------------------------------------------------------------- #
#                             Calculs                              #
# ---------------------------------------------------------------- #


=head1 FUNCTION get_regulation_fold_for_xls_from_log2_to_base10

 Prends en entrée en fold en log2 et accessoirement un arrays de folds en log2.
 Renvoie le fold et l'array de folds en base10 signés ainsi que la régulation (up ou down) correspondante.

=cut

sub get_regulation_fold_for_xls_from_log2_to_base10 {
    

    my ($fold, $array_folds) = @_;
    

    my $regulation;
    if ( $fold >= 0 ) {
        $regulation = "up";
        $fold = round((2**$fold), 2);
        if ( $array_folds ){
        	foreach(@$array_folds){
                $_ = round((2**$_), 2);
            }
        }
    }else{
        $regulation = "down";
        $fold = round((1/(2**$fold)), 2);
        if ( $array_folds ){
            foreach(@$array_folds){
                $_ = round((1/(2**$_)), 2);
            }
        }
    
    }


    return ($regulation, $fold, $array_folds);
    
}


=head1 FUNCTION get_regulation_fold_from_log2_to_base10

 Même fonction que get_regulation_fold_for_xls_from_log2_to_base10 mais sans l'arrondi

=cut

sub get_regulation_fold_from_log2_to_base10 {
    

    my ($fold, $array_folds) = @_;
    

    my $regulation;
    if ( $fold >= 0 ) {
        $regulation = "up";
        $fold = (2**$fold);
        if ( $array_folds ){
        	foreach(@$array_folds){
                $_ = (2**$_);
            }
        }
    }else{
        $regulation = "down";
        $fold = (1/(2**$fold));
        if ( $array_folds ){
            foreach(@$array_folds){
                $_ = (1/(2**$_));
            }
        }
    
    }


    return ($regulation, $fold, $array_folds);
    
}


=head1 FUNCTION get_regulation_fold_for_xls_from_base10_to_base10

 Prends en entrée en fold en base10 et accessoirement un arrays de folds en base10.
 Renvoie le fold et l'array de folds en base10 signés ainsi que la régulation (up ou down) correspondante.

=cut

sub get_regulation_fold_for_xls_from_base10_to_base10 {


    my ($fold, $array_folds) = @_;
    

    my $regulation;
    if ( $fold >= 1 ) {
        $regulation = "up";
        $fold = round($fold, 2);
        if ( $array_folds ){
        	foreach(@$array_folds){
                $_ = round($_, 2);
            }
        }
    }else{
        $regulation = "down";
        $fold = round((1/$fold), 2);
        if ( $array_folds ){
            foreach(@$array_folds){
                $_ = round((1/$_), 2);
            }
        }
    
    }


    return ($regulation, $fold, $array_folds);

}

=head1 FUNCTION get_regulation_fold_from_base10_to_base10

 Même fonction que get_regulation_fold_for_xls_from_base10_to_base10 mais sans l'arrondi

=cut

sub get_regulation_fold_from_base10_to_base10 {

    my ($fold) = @_;
    
    my $regulation;
    if ( $fold >= 1 ) {
        return ("up", $fold);
        
    }else{
        return ("down", (1/$fold));

    }
    
}


# ---------------------------------------------------------------- #
#                              Resume                              #
# ---------------------------------------------------------------- #

=head1 FUNCTION resume_annotation_sondes

 Ecrit dans le fichier excel passé en paramètre un résumé concernant l'annotation des sondes dans fasterb :
 Sondes analysables et anlysées en fonction de :
    le gc-content
    le ch
    l'expression
    la cible : entité, intron, séquence inter-génique

=cut

sub resume_annotation_sondes {
	
	my ($probes_db, $orga, $projet_num, $f_resume, $format_resume_titre, $format_resume_cell, $format_cell_no_center, $analyse) = @_;
	
	my $nb_sondes_min_gene = 6;
    my $nb_sondes_min_entite = 3;
    
    my ($nb_sondes, $nb_sondes_good_gc, $nb_sondes_bad_gc, $nb_sondes_good_ch, $nb_sondes_bad_ch, $nb_sondes_exp, $nb_sondes_non_exp, $nb_sondes_entites, $nb_sondes_introniques, $nb_sondes_non_exploitables, $nb_sondes_entites_analysables, $nb_sondes_entites_analysees) = &ResumeAnalyse::resume_sondes($probes_db, $orga, $projet_num);
    
    # Ecriture sur la feuille
    my $num_ligne = 8;
    $f_resume->set_column(0, 0, 25);
    $f_resume->set_column(2, 2, 20);
    $f_resume->write($num_ligne++, 0, "Sondes et entites analysees", $format_resume_titre);
    $num_ligne++;
    $f_resume->write($num_ligne++, 0, "Sondes", $format_resume_titre);
    $num_ligne++;
    ecriture(["Sur la puce", $nb_sondes], $f_resume, $num_ligne++, $format_resume_cell);
    ecriture(["Avec gc < 18", $nb_sondes_good_gc, "Avec gc > 18", $nb_sondes_bad_gc], $f_resume, $num_ligne++, $format_resume_cell);
    ecriture(["Non ch", $nb_sondes_good_ch, "Ch", $nb_sondes_bad_ch], $f_resume, $num_ligne++, $format_resume_cell);    
    ecriture(["Exprimees", $nb_sondes_exp, "Non exprimees", $nb_sondes_non_exp], $f_resume, $num_ligne++, $format_resume_cell);
    $num_ligne++;
    ecriture(["Ciblant des entites", $nb_sondes_entites], $f_resume, $num_ligne++, $format_resume_cell);    
    ecriture(["Introniques", $nb_sondes_introniques], $f_resume, $num_ligne++, $format_resume_cell);
    ecriture(["Non utilisees (inter-geniques, chevauchantes, non hybridees...)", $nb_sondes_non_exploitables], $f_resume, $num_ligne++, $format_cell_no_center);
    $num_ligne++;
    ecriture(["Analysables*", $nb_sondes_entites_analysables], $f_resume, $num_ligne++, $format_resume_cell);    
    ecriture(["Analysees*", $nb_sondes_entites_analysees], $f_resume, $num_ligne++, $format_resume_cell);

    # Légende
    if ( $analyse eq "transcription"){
        ecriture(["* analysable", "avec sonde : gc <18, non ch et ciblant une entite"], $f_resume, 36, $format_cell_no_center);
        ecriture(["* analysee", "avec sonde : gc <18, non ch, ciblant une entite et exprimee dans l'experience"], $f_resume, 37, $format_cell_no_center);
    }else{
        ecriture(["* analysable", "avec sonde : gc <18, non ch et ciblant une entite"], $f_resume, 52, $format_cell_no_center);
        ecriture(["* analysee", "avec sonde : gc <18, non ch, ciblant une entite et exprimee dans l'experience"], $f_resume, 53, $format_cell_no_center);
    }
	
}


=head1 FUNCTION resume_annotation_genes

 Ecrit dans le fichier excel passé en paramètre un résumé concernant les gènes fasterb analysables et analysés en transcription.

=cut

sub resume_annotation_genes {
	
    my ($probes_db, $orga, $projet_num, $f_resume, $format_resume_titre, $format_resume_cell) = @_;
    
    my $nb_sondes_min_gene = 6;
	
	my ($nb_genes_analysables, $nb_genes_analyses) = &ResumeAnalyse::genes_analysables_analysees($probes_db, $orga, $projet_num, $nb_sondes_min_gene);

    my $num_ligne = 25;
	
	$f_resume->write($num_ligne++, 0, "Genes", $format_resume_titre);
    $num_ligne++;
    ecriture(["Analysables*", $nb_genes_analysables], $f_resume, $num_ligne++, $format_resume_cell);    
    ecriture(["Analyses*", $nb_genes_analyses], $f_resume, $num_ligne++, $format_resume_cell);
	
}


=head1 FUNCTION resume_annotation_entites

 Ecrit dans le fichier excel passé en paramètre un résumé concernant les gènes et entités fasterdb analysables et analysés en épissage.

=cut

sub resume_annotation_entites {
	
    my ($probes_db, $orga, $projet_num, $f_resume, $format_resume_titre, $format_resume_cell, $format_cell_no_center) = @_;
    
    my $nb_sondes_min_entite = 3;
	
    my ($nb_genes_total_analysables, $nb_entites_total_analysables, $hash_nb_entites_analysables, $nb_genes_total_analyses, $nb_entites_total_analysees, $hash_nb_entites_analysees) = &ResumeAnalyse::entites_analysables_analysees($probes_db, $orga, $projet_num, $nb_sondes_min_entite);
    
    # Merging des colonnes
#    $f_resume->set_column(5, 5, 16);
#    $f_resume->set_column(8, 8, 20);

    # Ecriture sur la feuille
    my $num_ligne = 25;
    my $num_col   = 0;
    $f_resume->write($num_ligne++, $num_col, "Genes", $format_resume_titre);
    $num_ligne++;
    ecriture(["Analysables*",$nb_genes_total_analysables], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["Analyses*", $nb_genes_total_analyses], $f_resume, $num_ligne++, $format_resume_cell, $num_col);    
    $num_ligne++; $num_ligne++;
#    $num_ligne = 10;
#    $num_col = 8;
    $f_resume->write($num_ligne++, $num_col, "Entites", $format_resume_titre);
    $num_ligne++;
    ecriture(["Total analysables*", $nb_entites_total_analysables], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["exon", $hash_nb_entites_analysables->{"Exons"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["prom", $hash_nb_entites_analysables->{"Proms"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["polya", $hash_nb_entites_analysables->{"Polyas"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["intron-retention", $hash_nb_entites_analysables->{"Intron-retentions"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["donor", $hash_nb_entites_analysables->{"Donors"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["acceptor", $hash_nb_entites_analysables->{"Acceptors"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["deletion", $hash_nb_entites_analysables->{"Deletions"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    $num_ligne++;
    ecriture(["Total analysees*", $nb_entites_total_analysees], $f_resume, $num_ligne++, $format_resume_cell, $num_col);    
    ecriture(["exon", $hash_nb_entites_analysees->{1}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["prom", $hash_nb_entites_analysees->{2}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["polya", $hash_nb_entites_analysees->{3}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["intron-retention", $hash_nb_entites_analysees->{4}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["donor", $hash_nb_entites_analysees->{5}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["acceptor", $hash_nb_entites_analysees->{6}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["deletion", $hash_nb_entites_analysees->{7}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
	
}


=head1 FUNCTION resume_annotation_fat_polya

 Ecrit dans le fichier excel passé en paramètre un résumé concernant les 3'UTR fasterdb analysables et analysés en épissage.

=cut

sub resume_annotation_3primeUTR {
	
    my ($probes_db, $orga, $projet_num, $f_resume, $format_resume_titre, $format_resume_cell, $format_cell_no_center) = @_;
    
    my $nb_sondes_min_entite = 3;
    
    my ($nb_genes_analysables, $nb_entites_analysables, $nb_genes_analysees, $nb_entites_analysees) = &ResumeAnalyse::trois_primeUTR_analysables_analysees($probes_db, $orga, $projet_num, $nb_sondes_min_entite);
    
    # Merging des colonnes
#    $f_resume->set_column(5, 5, 16);
#    $f_resume->set_column(8, 8, 20);

    # Ecriture sur la feuille
    my $num_ligne = 25;
    my $num_col   = 0;
    $f_resume->write($num_ligne++, $num_col, "Genes", $format_resume_titre);
    $num_ligne++;
    ecriture(["Analysables*",$nb_genes_analysables], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["Analyses*", $nb_genes_analysees], $f_resume, $num_ligne++, $format_resume_cell, $num_col);    
    $num_ligne++; $num_ligne++;
#    $num_ligne = 10;
#    $num_col = 8;
    $f_resume->write($num_ligne++, $num_col, "3\'UTR", $format_resume_titre);
    $num_ligne++;
    ecriture(["analysables*", $nb_entites_analysables], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["analysees*", $nb_entites_analysees], $f_resume, $num_ligne++, $format_resume_cell, $num_col);    

}


=head1 FUNCTION resume_resultats_transcription

 Ecrit dans le fichier excel passé en paramètre les résultats de l'analyse au niveau transcriptionelle.

=cut

sub resume_resultats_transcription {
	
	my ($genes_no_fdr, $genes_fdr, $f_resume, $format_resume_titre, $format_resume_cell) = @_;

    my $num_ligne = 8;
    my $num_col = 5;
    $f_resume->set_column(5, 5, 30);
    $f_resume->set_column(9, 9, 13);
    $f_resume->set_column(9, 9, 13);
    $f_resume->set_column(11, 11, 18);
    $f_resume->write($num_ligne++, $num_col, "Resultats", $format_resume_titre);
    $num_ligne++;
    $f_resume->write($num_ligne++, $num_col, "Sans correction des p-valeurs", $format_resume_titre);
    $num_ligne++;
    ecriture(["Genes regules", $genes_no_fdr->{"total"}, "Genes up", $genes_no_fdr->{"up"}, "Genes down", $genes_no_fdr->{"down"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    $num_ligne++;
    $num_ligne++;
    $f_resume->write($num_ligne++, $num_col, "Avec correction des p-valeurs", $format_resume_titre);
    $num_ligne++;
    ecriture(["Genes regules", $genes_fdr->{"total"}, "Genes up", $genes_fdr->{"up"}, "Genes down", $genes_fdr->{"down"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
	
}


=head1 FUNCTION resume_resultats_splicing

 Ecrit dans le fichier excel passé en paramètre les résultats de l'analyse au niveau du slicing.

=cut

sub resume_resultats_splicing {
	
	my ($hash_resultats_sans_correction, $hash_resultats_avec_correction, $f_resume, $format_resume_titre, $format_resume_cell, $format_resume_intermediaire) = @_;

    my $num_ligne = 8;
    my $num_col   = 5;
    
    # Setting des colonnes
    $f_resume->set_column(5, 7, 35);

    # Print des résultats
    $f_resume->write($num_ligne, $num_col, "Resultats", $format_resume_titre);
    $num_ligne++;
    $num_ligne++;
    $f_resume->write($num_ligne++, $num_col, "Sans correction des p-valeurs", $format_resume_titre);
    $num_ligne++;
    ecriture(["Evenements fiables (fc gene < 2)", "Evenements moins fiables (fc gene >= 2)"], $f_resume, $num_ligne++, $format_resume_intermediaire, ($num_col+1));
    ecriture(["Nb entites up", $hash_resultats_sans_correction->{"fc_ok"}->{"entites_up"}, $hash_resultats_sans_correction->{"fc_mauv"}->{"entites_up"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["Nb entites down", $hash_resultats_sans_correction->{"fc_ok"}->{"entites_down"}, $hash_resultats_sans_correction->{"fc_mauv"}->{"entites_down"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["Nb entites total", ($hash_resultats_sans_correction->{"fc_ok"}->{"entites_up"}+$hash_resultats_sans_correction->{"fc_ok"}->{"entites_down"}), ($hash_resultats_sans_correction->{"fc_mauv"}->{"entites_up"}+$hash_resultats_sans_correction->{"fc_mauv"}->{"entites_down"})], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    $num_ligne++;
    $num_ligne++;
    $f_resume->write($num_ligne++, $num_col, "Avec correction des p-valeurs", $format_resume_titre);
    $num_ligne++;
    ecriture(["Evenements fiables (fc gene < 2)", "Evenements moins fiables (fc gene >= 2)"], $f_resume, $num_ligne++, $format_resume_cell, ($num_col+1));
    ecriture(["Nb entites up", $hash_resultats_avec_correction->{"fc_ok"}->{"entites_up"}, $hash_resultats_avec_correction->{"fc_mauv"}->{"entites_up"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["Nb entites down", $hash_resultats_avec_correction->{"fc_ok"}->{"entites_down"}, $hash_resultats_avec_correction->{"fc_mauv"}->{"entites_down"}], $f_resume, $num_ligne++, $format_resume_cell, $num_col);
    ecriture(["Nb entites total", ($hash_resultats_avec_correction->{"fc_ok"}->{"entites_up"}+$hash_resultats_avec_correction->{"fc_ok"}->{"entites_down"}), ($hash_resultats_avec_correction->{"fc_mauv"}->{"entites_up"}+$hash_resultats_avec_correction->{"fc_mauv"}->{"entites_down"})], $f_resume, $num_ligne++, $format_resume_cell, $num_col);

	
}


# ---------------------------------------------------------------- #
#                               Genes                              #
# ---------------------------------------------------------------- #


=head1 FUNCTION get_gene_identifiants_ensembl
 
 Prend en paramètre un identifiant ensembl.
 Renvoie un array contenant les identifiants ensembl d'un gène.
 0 : identifiant(s) humain
 1 : identifiant(s) souris
 
=cut

sub get_gene_identifiants_ensembl {
	
    my ($id_ensembl, $h_genes_ortholgues_humain, $h_genes_ortholgues_souris) = @_;
    
    my $tab_orthologue = ();
    
    # Récupère les orthologues correspondant
    if ( $id_ensembl =~ /^ENSMUS.*$/ ){
        $tab_orthologue = $h_genes_ortholgues_souris->{$id_ensembl};
    }else{
        $tab_orthologue = $h_genes_ortholgues_humain->{$id_ensembl};
    }
    
    # Transforme la liste des orthologues en string
    my $string_orthologue = (defined $tab_orthologue) ? join(' ', @$tab_orthologue) : "-";
    
    # Hash retourné
    my %r_hash_ensembl = ();
    if ( $id_ensembl =~ /^ENSMUS.*$/ ){
    	$r_hash_ensembl{"ensembl_humain"} = $string_orthologue;
        $r_hash_ensembl{"ensembl_souris"} = $id_ensembl;
    }else{
        $r_hash_ensembl{"ensembl_humain"} = $id_ensembl;
        $r_hash_ensembl{"ensembl_souris"} = $string_orthologue;
    }
    

    return \%r_hash_ensembl;
    
}


=head1 FUNCTION requete_genes_regulation

 Récupère les valeurs de regulation des gènes pour l'expérience traitée (fold et p-valeur).
 Retourne un hash dont la clé est l'id du gène et la value un hash avec la regulation (up ou down), le FC (en base 10) et la pvalue.

=cut

sub requete_genes_regulation_xls{
    

    my ($base, $table_trans, $est_paire, $fdr_corrigee) = @_;

    my %r_hash = ();
    
    my @champs_selection = ("`gene_id`", "`epi_fc`");
    
    if ( $fdr_corrigee ) {
        push(@champs_selection, "`epi_adjp`");
    }else{
        push(@champs_selection, "`epi_pval`");
    }

    my $requete =
       "SELECT ".join(', ', @champs_selection)."
        FROM $table_trans 
        WHERE `epi_fc` IS NOT NULL;";
        

    my $select = $base->prepare($requete);
        
    $select -> execute;
    
    while( my ( $id, $fold, $pvalue ) = $select -> fetchrow_array){
    	
    	my ($regulation, $fc, $folds) = &FonctionsXls::get_regulation_fold_for_xls_from_log2_to_base10($fold);
    	$pvalue = round($pvalue, 5);
    	
        my %hash_gene_regulation = ( "regulation" => $regulation,
                                     "fold"       => $fc,
                                     "pvalue"     => $pvalue );

        $r_hash{$id} = \%hash_gene_regulation;
        
    }

    $select -> finish;


    return \%r_hash;
    
}


# ---------------------------------------------------------------- #
#                              Entites                             #
# ---------------------------------------------------------------- #

=head1 FUNCTION requete_entite_caracteristiques

 Récupère les caractéristiques d'une entité donnée.
 Renvoie un hash (clé : carac, val : valeur de la carac).
 Tape dans la table mysql fait pour l'occasion.

=cut

sub requete_entite_caracteristiques_xls {

    my ($dbh, $table_entite, $id) = @_;

	my $select_id_oldschool_sth = $dbh->prepare(
		"SELECT id_elexir, type, id_gene, exon_pos, start_sur_gene, end_sur_gene, is_exon
		FROM $table_entite
		WHERE id = ?"
	);

	# On selectionne les caractéristiques de l'entité
	$select_id_oldschool_sth->execute($id);
	my $caracs_entite = $select_id_oldschool_sth->fetchrow_hashref;
	$select_id_oldschool_sth->finish;

	# Traduction du type
	my %name2num = (
		'exon' => 1,
		'prom' => 2,
		'polya' => 3,
		'donnor' => 5,
		'acceptor' => 6,
		'deletion' => 7,
		'intron-retention' => 4
	);

	# On défini la chaine position
	my $raw_pos = $caracs_entite->{'exon_pos'} . ':' . $caracs_entite->{'start_sur_gene'} . '-' . $caracs_entite->{'end_sur_gene'};

	my $pos = ($caracs_entite->{'type'} eq 'intron-retention')
		? 'i' . $raw_pos
		: 'e' . $raw_pos;

	# On retourne un hash d'entité à la old school
	return {
		'id' => $caracs_entite->{'id_elexir'},
		'num_type' => $name2num{$caracs_entite->{'type'}},
		'nom_type' => $caracs_entite->{'type'},
		'gene_id' => $caracs_entite->{'id_gene'},
		'position' => $pos,
		'sequence' => '',
		'is_exon' => $caracs_entite->{'is_exon'}
	};

}






1;
__END__
