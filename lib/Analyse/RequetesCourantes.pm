=head1 NAME

 RequetesCourantes.pm - Fonctions de sélection pour les analyses

=head1 SYNOPSIS

 use RequetesCourantes;
 &RequetesCourantes::insertion_base($base);

=head1 DESCRIPTION

 A remplir.

=cut

package RequetesCourantes;
use strict;
use warnings;


#-----------------------------------------------------------------#
# # # # # # # # # # # #  REQUETES GLOBALES  # # # # # # # # # # # #
#-----------------------------------------------------------------#

# cad : s'appliquent sur la totalité des tables


#-----------------------------------------------------------------#
#                         Requetes sur sondes                     #
#-----------------------------------------------------------------#

=head1 FUNCTION requete_sondes_intensites_base10

 Récupère les intensités de toutes les sondes de la puce en base décimale.
 Retourne un hash dont la clé est l'id de la sonde et la value est un pointeur sur un array contenant les intensités (controls puis tests, ordre croissant des réplicats).

=cut

sub requete_sondes_intensites_base10{
    

    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test) = @_;

    my %r_hash = ();
    
    my @champs_requete = ();
    for(my $i = 0; $i < $nb_repl_cont; $i++){
        push(@champs_requete, "`control".($i + 1)."`");
    }
    for(my $i = 0; $i < $nb_repl_test; $i++){
        push(@champs_requete, "`test".($i + 1)."`");
    }

    my $requete =
       "SELECT `probe_id`, ".join(', ', @champs_requete)."
        FROM `".$projet_num."_intensites` ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my @data = $select -> fetchrow_array){
        my $sonde_id = shift(@data);
        $r_hash{$sonde_id} = \@data;
    }
    $select -> finish;
    

    return \%r_hash;
    
}

=head1 FUNCTION requete_sondes_intensites_log2

 Récupère les intensités de toutes les sondes de la puce en log2.
 Retourne un hash dont la clé est l'id de la sonde et la value est un pointeur sur un array contenant les intensités (controls puis tests, ordre croissant des réplicats).

=cut

sub requete_sondes_intensites_log2{
    

    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test) = @_;

    my %r_hash = ();
    
    my @champs_requete = ();
    for(my $i = 0; $i < $nb_repl_cont; $i++){
        push(@champs_requete, "LOG2(`control".($i + 1)."`)");
    }
    for(my $i = 0; $i < $nb_repl_test; $i++){
        push(@champs_requete, "LOG2(`test".($i + 1)."`)");
    }

    my $requete =
       "SELECT `probe_id`, ".join(', ', @champs_requete)."
        FROM `".$projet_num."_intensites` ; ";
        
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my @data = $select -> fetchrow_array){
        my $sonde_id = shift(@data);
        foreach(@data){
        	$_ = log2($_);
        }
        $r_hash{$sonde_id} = \@data;
    }
    $select -> finish;
    

    return \%r_hash;
    
}

=head1 FUNCTION requete_sondes_fc_base10

 Récupère les folds de toutes les sondes de la puce en base décimale.
 Retourne un hash dont la clé est l'id de la sonde et la value est un pointeur sur un array contenant les folds de la sonde en base décimale.

=cut

sub requete_sondes_fc_base10 {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test) = @_;

    my %r_hash = ();
    
    my @champs_requete = ();
    if ( $est_paire ){
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`fc".($i + 1)."`");
        }
    }else{
        push(@champs_requete, "`fc`");
    }
    
    my $requete =
       "SELECT `probe_id`, ".join(', ', @champs_requete)."
        FROM `".$projet_num."_fold` ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my @data = $select -> fetchrow_array){
        my $sonde_id = shift(@data);
        $r_hash{$sonde_id} = \@data;
    }
    $select -> finish;
    

    return \%r_hash;

}

=head1 FUNCTION requete_sondes_fc_log2

 Récupère les folds de toutes les sondes de la puce en log2.
 Retourne un hash dont la clé est l'id de la sonde et la value est un pointeur sur un array contenant les folds de la sonde en log2.
 On récupère les valeurs en log2 -> pas de biais pour faire des rapports de folds (sinon biais avec valeurs inférieures à 1)

=cut

sub requete_sondes_fc_log2 {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test) = @_;

    my %r_hash = ();
    
    my @champs_requete = ();
    if ( $est_paire ){
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "LOG2(`fc".($i + 1)."`)");
        }
    }else{
        push(@champs_requete, "LOG2(`fc`)");
    }
    
    my $requete =
       "SELECT `probe_id`, ".join(', ', @champs_requete)."
        FROM `".$projet_num."_fold` ; ";
        
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my @data = $select -> fetchrow_array){
        my $sonde_id = shift(@data);
        $r_hash{$sonde_id} = \@data;
    }
    $select -> finish;


    return \%r_hash;

}

=head1 FUNCTION requete_sondes_si_log2

 Récupère les si de toutes les sondes de la puce en log2.
 Retourne un hash dont la clé est l'id du gène et la value est un pointeur sur un hash contenant les si des sondes en log2.
 On récupère les valeurs en log2 -> pas de biais pour faire des rapports de folds (sinon biais avec valeurs inférieures à 1)

=cut

sub requete_sondes_si_log2 {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test) = @_;

    my %r_hash = ();
    
    my @champs_requete = ();
    if ( $est_paire ){
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`SI".($i + 1)."`");
        }
    }else{
        push(@champs_requete, "`SI`");
    }
    
    my $requete =
       "SELECT `probe_id`, `gene_id`, ".join(', ', @champs_requete)."
        FROM `".$projet_num."_si_sondes` ; ";
        
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my @data = $select -> fetchrow_array){
        my $sonde_id = shift(@data);
        my $gene_id  = shift(@data);
        $r_hash{$gene_id}->{$sonde_id} = \@data;
    }
    $select -> finish;


    return \%r_hash;

}

=head1 FUNCTION requete_sondes_pvalues_dabg

 Récupère les p-valeurs de dabg des sondes de la puce (pour chaque réplicat de chaque condition).
 Retourne un hash dont la clé est l'id de la sonde et la value est un pointeur sur un array contenant les p-values (controls puis tests, ordre croissant des réplicats).

=cut

sub requete_sondes_pvalues_dabg {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test) = @_;

    my %r_hash = ();
    
    my @champs_requete = ();
    for(my $i = 0; $i < $nb_repl_cont; $i++){
        push(@champs_requete, "`control".($i + 1)."`");
    }
    for(my $i = 0; $i < $nb_repl_test; $i++){
        push(@champs_requete, "`test".($i + 1)."`");
    }

    my $requete =
       "SELECT `probe_id`, ".join(', ', @champs_requete)."
        FROM `".$projet_num."_dabg` ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my @data = $select -> fetchrow_array){
        my $sonde_id = shift(@data);
        $r_hash{$sonde_id} = \@data;
    }
    $select -> finish;


    return \%r_hash;

}

=head1 FUNCTION requete_sondes_expression

 Récupère l'expression des sondes de la puce.
 Renvoie un hash dont la clé est l'id de la sonde et la value est un booléen définissant la sonde comme exprimée ou non dans l'expérience.

=cut

sub requete_sondes_expression {
    
    
    my ($base, $projet_num) = @_;

    my %r_hash = ();
    
    my $requete =
       "SELECT `probe_id`, `expression`
        FROM `".$projet_num."_dabg` ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my ($probe_id, $probe_expression) = $select -> fetchrow_array){
        $r_hash{$probe_id} = $probe_expression;
    }
    $select -> finish;


    return \%r_hash;

}


#-----------------------------------------------------------------#
#                         Requetes sur gènes                      #
#-----------------------------------------------------------------#


=head1 FUNCTION requete_genes_caracteristiques

 Récupère les caractéristiques des gènes fasterdb (table gene de fasterdb).
 Renvoie un hash dont la clé est l'id du gène et la value est un pointeur sur un hash contenant les caractéristiques du gène.

=cut

sub requete_genes_caracteristiques {
    
    
    my ($base) = @_;

    my %r_hash = ();
    
    my $requete =
       "SELECT `id`, `stable_id_ensembl`, `official_symbol`, `description`, `chromosome`, `strand`, `start_sur_chromosome`, `end_sur_chromosome`, `sequence`, `longueur`
        FROM `genes` ;";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my ( $id, $ensembl, $symbol, $description, $chr, $strand, $start, $end, $seq, $long ) = $select -> fetchrow_array){
        my %h_carac_gene = ( "ensembl" => $ensembl,
                             "symbol"  => $symbol,
                             "desc"    => $description,
                             "chr"     => $chr,
                             "strand"  => $strand,
                             "start"   => $start,
                             "end"     => $end,
                             "seq"     => $seq,
                             "long"    => $long);
        $r_hash{$id} = \%h_carac_gene;
    }
    $select -> finish;


    return \%r_hash;

}

=head1 FUNCTION recup_nb_exons_gene

 Renvoie un hash avec le nombre d'exons par gène

=cut

sub recup_nb_exons_gene {

    
    my ($faster_db) = @_;

    my %r_hash = ();
    
    my $requete =
        "SELECT `id_gene` , count( `id` ) AS nb_exons
        FROM `exons_genomiques`
        GROUP BY `id_gene`";
        
    my $select = $faster_db -> prepare ($requete);
    $select -> execute;
    while (my ($gene_id, $nb_exons) = $select -> fetchrow_array){
        $r_hash{$gene_id} = $nb_exons;
    }    
    $select -> finish;

    
    return \%r_hash;

}

=head1 FUNCTION requete_genes_orthologues

 Récupère les gènes orthologues humain et souris.
 Renvoie 2 hash : l'un dont les clés sont les identifiants ensembl humain et la value une ref sur un array contenant tous les identifaints souris correspondants, l'autre : et vice-versa... 

=cut

sub requete_genes_orthologues {
	
    
    my ($base) = @_;

    my %r_hash_souris = ();
    my %r_hash_humain = ();
    
    my $requete =
       "SELECT `genes_humains`, `genes_souris`
        FROM `genes_orthologues` ;";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my ( $id_humain, $id_souris ) = $select -> fetchrow_array){
    	push(@{$r_hash_humain{$id_humain}}, $id_souris);
        push(@{$r_hash_souris{$id_souris}}, $id_humain);
    }
    $select -> finish;


    return (\%r_hash_humain, \%r_hash_souris);
    
}

=head1 FUNCTION requete_genes_expression_log2

 Récupère la regulation des gènes pour lesquels elle a été calculée.
 Renvoie un hash dont la clé est l'id du gène et la value est un pointeur sur un array contenant les valeurs d'expression du gène (en log2).
 1ère méthode = par réplicats si l'expérience est pairée.

=cut

sub requete_genes_expression_log2 {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test) = @_;

    my %r_hash = ();
    
    my @champs_requete = ();
    
    if ( $est_paire ){
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`control".($i + 1)."`");
        }
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`test".($i + 1)."`");
        }
    }else{
        push(@champs_requete, "`control`, `test`");
    }
    
    my $requete =
       "SELECT `gene_id`, ".join(', ', @champs_requete)."
        FROM `".$projet_num."_transcription` ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my @data = $select -> fetchrow_array){
        my $gene_id = shift(@data);
        $r_hash{$gene_id} = \@data;
    }
    $select -> finish;


    return \%r_hash;

}

=head1 FUNCTION requete_genes_fold_epissage

 Récupère la regulation des gènes pour lesquels elle a été calculée.
 Renvoie un hash dont la clé est l'id du gène et la value est un pointeur sur un array contenant les fcs du gène (en log2).
 1ère méthode = par réplicats si l'expérience est pairée.

=cut

sub requete_genes_fold_epissage {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test) = @_;

    my %r_hash = ();
    
    my $requete =
       "SELECT `gene_id`, `epi_fc`
        FROM `".$projet_num."_transcription` WHERE `epi_fc` IS NOT NULL  ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    while( my ($gene_id, $fold) = $select -> fetchrow_array){
        $r_hash{$gene_id} = $fold;
    }
    $select -> finish;


    return \%r_hash;

}


#-----------------------------------------------------------------#
# # # # # # # # # # #   REQUETES SPECIFIQUES  # # # # # # # # # # #
#-----------------------------------------------------------------#

# cad = s'appliquent sur un élément des tables en particulier


#----------------------------------------------------------------#
#                         Requetes sur sonde                     #
#----------------------------------------------------------------#

=head1 FUNCTION requete_sonde_intensites_base10

 Récupère les intensités d'une sonde passée en paramètre.
 Retourne un hash auquel on ajoute la sonde passé en paremètre.

=cut

sub requete_sonde_intensites_base10{
    

    my ($base, $projet_num, $nb_repl_cont, $nb_repl_test, $sonde_id) = @_;

    my @champs_requete = ();
    for(my $i = 0; $i < $nb_repl_cont; $i++){
        push(@champs_requete, "`control".($i + 1)."`");
    }
    for(my $i = 0; $i < $nb_repl_test; $i++){
        push(@champs_requete, "`test".($i + 1)."`");
    }

    my $requete =
       "SELECT ".join(', ', @champs_requete)."
        FROM `".$projet_num."_intensites` 
        WHERE `probe_id` = $sonde_id ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    my @data = $select -> fetchrow_array;
    $select -> finish;
    

    return \@data;
    
}

=head1 FUNCTION requete_sonde_intensites_log2

 Récupère les intensités d'une sonde passée en paramètre.
 Retourne un hash auquel on ajoute la sonde passé en paremètre.

=cut

sub requete_sonde_intensites_log2{
    

    my ($base, $projet_num, $nb_repl_cont, $nb_repl_test, $sonde_id) = @_;

    my @champs_requete = ();
    for(my $i = 0; $i < $nb_repl_cont; $i++){
        push(@champs_requete, "LOG2(`control".($i + 1)."`)");
    }
    for(my $i = 0; $i < $nb_repl_test; $i++){
        push(@champs_requete, "LOG2(`test".($i + 1)."`)");
    }

    my $requete =
       "SELECT ".join(', ', @champs_requete)."
        FROM `".$projet_num."_intensites` 
        WHERE `probe_id` = $sonde_id ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    my @data = $select -> fetchrow_array;
    $select -> finish;
    

    return \@data;
    
}

=head1 FUNCTION requete_sonde_fc_base10

 Récupère les folds de toutes les sondes de la puce en base décimale.
 Retourne un hash dont la clé est l'id de la sonde et la value est un pointeur sur un array contenant les folds de la sonde en base décimale.

=cut

sub requete_sonde_fc_base10 {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test, $sonde_id) = @_;

    my @champs_requete = ();
    if ( $est_paire ){
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`fc".($i + 1)."`");
        }
    }else{
        push(@champs_requete, "`fc`");
    }
    
    my $requete =
       "SELECT ".join(', ', @champs_requete)."
        FROM `".$projet_num."_fold`
        WHERE `probe_id` = $sonde_id ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    my @data = $select -> fetchrow_array;
    $select -> finish;


    return \@data;

}

=head1 FUNCTION requete_sonde_fc_log2

 Récupère les folds de toutes les sondes de la puce en log2.
 Retourne un hash dont la clé est l'id de la sonde et la value est un pointeur sur un array contenant les folds de la sonde en log2.
 On récupère les valeurs en log2 -> pas de biais pour faire des rapports de folds (sinon biais avec valeurs inférieures à 1)

=cut

sub requete_sonde_fc_log2 {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test, $sonde_id) = @_;

    my @champs_requete = ();
    if ( $est_paire ){
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "LOG2(`fc".($i + 1)."`)");
        }
    }else{
        push(@champs_requete, "LOG2(`fc`)");
    }
    
    my $requete =
       "SELECT ".join(', ', @champs_requete)."
        FROM `".$projet_num."_fold`
        WHERE `probe_id` = $sonde_id ; ";
        
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    my @data = $select -> fetchrow_array;
    $select -> finish;


    return \@data;

}

=head1 FUNCTION requete_sonde_si_log2

 Récupère les si de toutes les sondes de la puce en log2.
 Retourne un hash dont la clé est l'id du gène et la value est un pointeur sur un hash contenant les si des sondes en log2.
 On récupère les valeurs en log2 -> pas de biais pour faire des rapports de folds (sinon biais avec valeurs inférieures à 1)

=cut

sub requete_sonde_si_log2 {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test, $sonde_id, $gene_id) = @_;

    my @champs_requete = ();
    if ( $est_paire ){
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`SI".($i + 1)."`");
        }
    }else{
        push(@champs_requete, "`SI`");
    }
    
    my $requete =
       "SELECT ".join(', ', @champs_requete)."
        FROM `".$projet_num."_si_sondes`
        WHERE `probe_id` = $sonde_id 
        AND `gene_id` = $gene_id; ";
        
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    my @data = $select -> fetchrow_array;
    $select -> finish;


    return \@data;

}

=head1 FUNCTION requete_sonde_pvalues_dabg

 Récupère les p-valeurs de dabg des sondes de la puce (pour chaque réplicat de chaque condition).
 Retourne un hash dont la clé est l'id de la sonde et la value est un pointeur sur un array contenant les p-values (controls puis tests, ordre croissant des réplicats).

=cut

sub requete_sonde_pvalues_dabg {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test, $sonde_id) = @_;

    my @champs_requete = ();
    for(my $i = 0; $i < $nb_repl_cont; $i++){
        push(@champs_requete, "`control".($i + 1)."`");
    }
    for(my $i = 0; $i < $nb_repl_test; $i++){
        push(@champs_requete, "`test".($i + 1)."`");
    }

    my $requete =
       "SELECT ".join(', ', @champs_requete)."
        FROM `".$projet_num."_dabg`
        WHERE `probe_id` = $sonde_id ;";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    my @data = $select -> fetchrow_array;
    $select -> finish;


    return \@data;

}

=head1 FUNCTION requete_sonde_expression

 Récupère l'expression des sondes de la puce.
 Renvoie un hash dont la clé est l'id de la sonde et la value est un booléen définissant la sonde comme exprimée ou non dans l'expérience.

=cut

sub requete_sonde_expression {
    
    
    my ($base, $projet_num, $sonde_id) = @_;

    my %r_hash = ();
    
    my $requete =
       "SELECT `expression`
        FROM `".$projet_num."_dabg` 
        WHERE `probe_id` = $sonde_id ; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    my $probe_expression = $select -> fetchrow_array;
    $select -> finish;


    return $probe_expression;

}


#----------------------------------------------------------------#
#                         Requetes sur gènes                     #
#----------------------------------------------------------------#


=head1 FUNCTION requete_gene_expression_log2

 Récupère la regulation des gènes pour lesquels elle a été calculée.
 Renvoie un hash dont la clé est l'id du gène et la value est un pointeur sur un array contenant les valeurs d'expression du gène (en log2).

=cut

sub requete_gene_expression_log2 {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test, $gene_id) = @_;

    my @champs_requete = ();
    
    if ( $est_paire ){
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`control".($i + 1)."`");
        }
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`test".($i + 1)."`");
        }
    }else{
        push(@champs_requete, "`control`, `test`");
    }
    
    my $requete =
       "SELECT ".join(', ', @champs_requete)."
        FROM `".$projet_num."_transcription` 
        WHERE `gene_id` = $gene_id; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    my @data = $select -> fetchrow_array;
    $select -> finish;


    return \@data;

}


#----------------------------------------------------------------#
#                        Requetes sur entités                    #
#----------------------------------------------------------------#


=head1 FUNCTION requete_entite_expression_log2

 Récupère la regulation d'une entite.
 Renvoie une ref sur array contenant les valeurs d'expression de l'entité (en log2).

=cut

sub requete_entite_expression_log2 {
    
    
    my ($base, $projet_num, $est_paire, $nb_repl_cont, $nb_repl_test, $entite_type, $entite_id) = @_;

    my @champs_requete = ();
    
    if ( $est_paire ){
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`control".($i + 1)."`");
        }
        for(my $i = 0; $i < $nb_repl_cont; $i++){
            push(@champs_requete, "`test".($i + 1)."`");
        }
    }else{
        push(@champs_requete, "`control`, `test`");
    }
    
    my $requete =
       "SELECT ".join(', ', @champs_requete)."
        FROM `".$projet_num."_splicing` 
        WHERE `entite_type` = $entite_type
        AND `id_entite` = $entite_id; ";
    

    my $select = $base->prepare($requete);
        
    $select -> execute;
    my @data = $select -> fetchrow_array;
    $select -> finish;


    return \@data;

}


















1;
__END__
