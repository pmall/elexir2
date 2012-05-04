=head1 NAME

 ResumeAnalyse.pm

=head1 SYNOPSIS

 use ResumeAnalyse;
 &ResumeAnalyse::resume_sondes();

=head1 DESCRIPTION

 Fonctions dédiées à produire de brèves stat des sondes, gènes et entités traitées lors des analyses (en fonction des caractéristiques des sondes).

=cut

package ResumeAnalyse;
use strict;
use warnings;

=head1 FUNCTION resume_sondes

 Résume le nombre de sondes (non) analysables et (non) analysées.
 En fonction de : gc-content, est_ch, est_exprimée, cible une entité, cible un intron, , cible une séquence inter-génique...

=cut

sub resume_sondes {

    my ($base, $orga, $num_projet) = @_;
    
    # Infos identiques pour tous les projets -> dans resume/resume_sondes.txt
    my $h_sondes_analysables = (); #&General::fichier_to_hash("/home/elexir/analyses/analyse_puces/0_annotation/resume/".$orga."_resume_sondes.txt");
    my $nb_sondes            = $h_sondes_analysables->{"toutes"};
    my $nb_sondes_good_gc    = $h_sondes_analysables->{"bon_gc"};
    my $nb_sondes_bad_gc     = $h_sondes_analysables->{"mauv_gc"};
    my $nb_sondes_good_ch    = $h_sondes_analysables->{"non_ch"};
    my $nb_sondes_bad_ch     = $h_sondes_analysables->{"ch"};
    
    # Nb sondes sur la puce exprimée dans l'expérience analysée (expression = 1 avec tab dabg)
    my $req = "SELECT count(*) FROM `".$num_projet."_dabg` WHERE `expression` = 1;";
    my $select = $base -> prepare ($req);
    $select -> execute;
    my $nb_sondes_exp = $select -> fetchrow_array;
    $select -> finish;
    my $nb_sondes_non_exp = ($nb_sondes - $nb_sondes_exp);
    
    # Nombre de sondes ciblant des entités et nb sondes introniques
    ###  Pas de sélection à part sondes anti-sens et entite_type != 8 (algo particulier)
    my $nb_sondes_entites          = $h_sondes_analysables->{"exoniques"};
    my $nb_sondes_introniques      = $h_sondes_analysables->{"introniques"};
    my $nb_sondes_non_exploitables = $h_sondes_analysables->{"non utilisees"};
    
    # Nombre de sondes analysables et analysées
    ### Sondes analysables = critères constants
    ###     - sondes ciblant des entites, avec gc ok et non ch
    ### Sondes analysées = critères constants + expression
    ###     - sondes ciblant des entites, avec gc ok, non ch et exprimées dans l'expérience
    my $nb_sondes_entites_analysables = $h_sondes_analysables->{"analysables"};
    $req =
        "SELECT count( DISTINCT m.`probe_id` )
        FROM `".$orga."_probes_status` m, ".$num_projet."_dabg dp
        WHERE m.`align` = 'as'
        AND `entite_type` != 0
        AND `entite_type` != 8
        AND m.`gc_content` <18
        AND m.`nb_occ` =1 
        AND m.probe_id = dp.probe_id 
        AND dp.expression = 1 ;";
    $select = $base -> prepare ($req);
    $select -> execute;
    my $nb_sondes_analysees = $select -> fetchrow_array;
    $select -> finish;

    return ($nb_sondes, $nb_sondes_good_gc, $nb_sondes_bad_gc, $nb_sondes_good_ch, $nb_sondes_bad_ch, $nb_sondes_exp, $nb_sondes_non_exp, $nb_sondes_entites, $nb_sondes_introniques, $nb_sondes_non_exploitables, $nb_sondes_entites_analysables, $nb_sondes_analysees);

}    


=head1 FUNCTION genes_analysables_analysees

 Nombre de gènes analysables et analysées
 Gènes analysables = critères constants
     - au moins $nb_sondes_min_gene sondes exoniques, avec gc ok et non ch
 Gènes analysées = critères constants + expression + lissage
     - au moins $nb_sondes_min_gene sondes exoniques, avec gc ok, non ch et exprimées dans l'expérience APRES LISSAGE
 A partir des tables probes_status et transcription

=cut

sub genes_analysables_analysees {

    my ($base, $orga, $num_projet, $nb_sondes_min_gene) = @_;
    

    #---------------------- Gènes analysables ------------------#

    # Infos identiques pour tous les projets -> dans resume/resume_genes.txt
    my $h_genes_analysables  = &General::fichier_to_hash("/home/elexir/analyses/analyse_puces/0_annotation/resume/".$orga."_resume_genes.txt");
    my $nb_genes_analysables = $h_genes_analysables->{"analysables_transcription"};


    #------------------------ Gènes analysés --------------------#

    my $req =
        "SELECT count( `gene_id` )
        FROM `".$num_projet."_transcription` ;";
    my $select = $base -> prepare ($req);
    $select -> execute;
    my $nb_genes_analyses = $select -> fetchrow_array;
    $select -> finish;

    return ($nb_genes_analysables, $nb_genes_analyses);
    
}


=head1 FUNCTION entites_analysables_analysees

 Nombre de gènes analysables et analysées
 Entités analysables = critères constants
     - au moins $nb_sondes_min_entite sondes, avec gc ok et non ch
 Entités analysées = critères constants + expression + lissage
     - au moins $nb_sondes_min_entite sondes, avec gc ok, non ch et exprimées dans l'expérience
 A partir des tables probes_status et si_entites

=cut

sub entites_analysables_analysees {

    my ($base, $orga, $num_projet, $nb_sondes_min_entite) = @_;
    

    #---------------------- Entites analysables ------------------#

    # Infos identiques pour tous les projets -> dans resume/resume_entites.txt
    my $h_entites_analysables        = &General::fichier_to_hash("/home/elexir/analyses/analyse_puces/0_annotation/resume/".$orga."_resume_entites.txt");
    my $nb_entites_total_analysables = $h_entites_analysables->{"entites_analysables"};

    # Gènes analysables
    my $req =
        "SELECT DISTINCT `gene_id`
        FROM `".$orga."_probes_status`
        WHERE `align` = 'as'
        AND `entite_type` != 8
        AND `gc_content` <18
        AND `nb_occ` =1
        AND `gene_id` IN (SELECT `gene_id` FROM `".$num_projet."_transcription` WHERE `epi_fc` IS NOT NULL)
        GROUP BY `entite_id`
        HAVING count( `probe_id` >".($nb_sondes_min_entite-1)." ) ;";
    my $select = $base -> prepare ($req);
    $select -> execute;
    my $nb_genes_total_analysables = $select -> rows;
    $select -> finish;

    #----------------------- Entites analysees -------------------#
    
    # Gènes analysés
    $req =
        "SELECT distinct `gene_id`
        FROM `".$num_projet."_splicing` 
        WHERE `entite_type` != 8 ;";
    $select = $base -> prepare ($req);
    $select -> execute;
    my $nb_genes_total_analyses = $select -> rows;
    $select -> finish;

    my %hash_nb_entites_analysees = ();
    my $nb_entites_total_analysees = 0;
    # Pour chaque type d'entité (7 au total)
    for( my $i=1 ; $i < 8 ; $i++ ){
        $req =
            "SELECT count( `id_entite` )
            FROM `".$num_projet."_splicing`
            WHERE `entite_type` = $i ;";
        $select = $base -> prepare ($req);
        $select -> execute;
        my $nb_entites = $select -> fetchrow_array;
        $select -> finish;
        
        $hash_nb_entites_analysees{$i} = $nb_entites;
        $nb_entites_total_analysees += $nb_entites;
    }

    return ($nb_genes_total_analysables, $nb_entites_total_analysables, $h_entites_analysables, $nb_genes_total_analyses, $nb_entites_total_analysees, \%hash_nb_entites_analysees);
    
}


=head1 FUNCTION trois_primeUTR_analysables_analysees

 Nombre de gènes analysables et analysées
 Entités analysables = critères constants
     - au moins $nb_sondes_min_entite sondes, avec gc ok et non ch
 Entités analysées = critères constants + expression + lissage
     - au moins $nb_sondes_min_entite sondes, avec gc ok, non ch et exprimées dans l'expérience
 A partir des tables probes_status et si_entites

=cut

sub trois_primeUTR_analysables_analysees {

    my ($base, $orga, $num_projet, $nb_sondes_min_entite) = @_;
    

    #---------------------- Entites analysables ------------------#

    # Infos identiques pour tous les projets -> dans resume/resume_entites.txt
    my $h_entites_analysables        = &General::fichier_to_hash("/home/elexir/analyses/analyse_puces/0_annotation/resume/".$orga."_resume_3primeUTR.txt");
    my $nb_entites_analysables = $h_entites_analysables->{"entites_analysables"};

    # Gènes analysables
    my $req =
        "SELECT DISTINCT `gene_id`
        FROM `".$orga."_probes_status`
        WHERE `align` = 'as'
        AND `entite_type` = 8
        AND `gc_content` <18
        AND `nb_occ` =1
        AND `gene_id` IN (SELECT `gene_id` FROM `".$num_projet."_transcription` WHERE `epi_fc` IS NOT NULL)
        GROUP BY `entite_id`
        HAVING count( `probe_id` >".($nb_sondes_min_entite-1)." ) ;";
    my $select = $base -> prepare ($req);
    $select -> execute;
    my $nb_genes_analysables = $select -> rows;
    $select -> finish;

    #----------------------- Entites analysees -------------------#
    
    # Gènes analysés
    $req =
        "SELECT count( `gene_id` )
        FROM `".$num_projet."_splicing` 
        WHERE `entite_type` = 8 ;";
    $select = $base -> prepare ($req);
    $select -> execute;
    my $nb_genes_analyses = $select -> fetchrow_array;
    $select -> finish;

    my %hash_nb_entites_analysees = ();
    $req =
        "SELECT count( `id_entite` )
        FROM `".$num_projet."_splicing`
        WHERE `entite_type` = 8 ;";
    $select = $base -> prepare ($req);
    $select -> execute;
    my $nb_entites_analysees = $select -> fetchrow_array;
    $select -> finish;

    return ($nb_genes_analysables, $nb_entites_analysables, $nb_genes_analyses, $nb_entites_analysees);
    
}




1;
__END__
