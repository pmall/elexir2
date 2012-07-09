package Stats;
use strict;
use warnings;
use List::Util qw(min);
use List::MoreUtils qw(uniq);
use Statistics::Distributions;
use lib $FindBin::Bin;
use Math;
use Exporter qw(import);

our @EXPORT = qw(somme_fisher ttest adjust_pvals);

# ==============================================================================
# Somme les p values de la liste passé en parametre selon la méthode de fisher
# ==============================================================================

sub somme_fisher{

	my($ref_pvalues) = @_;

	# On somme les pvalues selon la méthode de fisher (suit une loi X²)
	my $sum_logs = 0;

	foreach(@{$ref_pvalues}){ $sum_logs+= log($_); }

	my $t = -2 * $sum_logs;

	# Nombre de degrés de liberté pour ce nombre de pvalues
	my $df = 2 * @{$ref_pvalues};

	# On calcule la prob qu'une loi de X² à df degré de liberté soit
	# supérieur à t
	my $pvalue = Statistics::Distributions::chisqrprob($df, $t);

	return $pvalue;

}

# ==============================================================================
# Effectue un ttest à partir d'une valeur moyenne/mediane/whatever et de la
# liste des échantillons qui a permi de calculer cette valeur
# ==============================================================================

sub ttest{

	my($ref_samples, $alternative) = @_;

	# On formatte et valide l'alternative
	if($alternative == 0){
		$alternative = 'lesser'
	}elsif($alternative == 1){
		$alternative = 'greater'
	}elsif(!($alternative eq 'lesser'
		or $alternative eq 'greater'
		or $alternative eq 'twosided')){

		die('ttest : l\'alternative doit être 0, 1, lesser, greater ou twosided');

	}

	# Si tout les fc sont identiques on bouge le premier de 0.01
	# sinon sd(@samples) = 0 et erreur
	if(uniq(@{$ref_samples}) == 1){ $ref_samples->[0]+= 0.01; }

	# On calcule t valeur de notre sample
	my $t = mean(@{$ref_samples})/(sd_est(@{$ref_samples})/(@{$ref_samples}**0.5));

	# On recherche la proba d'avoir une valeur t plus élevée pour
	# ce degré de liberté == alternative greater
	my $pvalue = Statistics::Distributions::tprob(@{$ref_samples} - 1, $t);

	# Selon l'alternative demandé on calcule la pvalue
	# greater on laisse tel quel
	if($alternative eq 'lesser'){ $pvalue = 1 - $pvalue; }
	if($alternative eq 'twosided'){ $pvalue = 2 * $pvalue; }

	# On retourne la p value
	return $pvalue;

}

# ==============================================================================
# Fonction correction pvalues
# ==============================================================================

sub adjust_pvals{

	# On classe les pvalues (définies) dans l'ordre croissant
	my @list_tri = (sort {$a <=> $b} (grep { defined $_ } @_));

	# On corrige les pvaleurs
	my @list_cor = ();

	for(my $i = 0; $i < @list_tri; $i++){

		my $value_cor = (@list_tri / ($i + 1)) * $list_tri[$i];

		push(@list_cor, $value_cor);

	}

	# On les "classe" "en escalier" :)
	my @list_cor_ord = ();

	my $min = min(@list_cor);

	for(my $i = 0; $i < @list_cor; $i++){

		push(@list_cor_ord, $min);

		if($list_cor[$i] == $min){

			$min = min(@list_cor[($i + 1)..$#list_tri]);

		}

	}

	# On associe les valeurs de pvalue aux valeurs de pvalue corrigée
	my %h_pval_pvalcor = ();

	for(my $i = 0; $i < @list_tri; $i++){

		$h_pval_pvalcor{$list_tri[$i]} = $list_cor_ord[$i];

	}

	# On refait une liste avec les valeurs corrigées, dans le bon ordre
	my @list_cor_ordre_origine = ();

	foreach my $val (@_){

		my $val_cor = (defined $val) ? $h_pval_pvalcor{$val} : undef;

		push(@list_cor_ordre_origine, $val_cor);

	}

	# On retourne la liste dans le bon ordre
	return @list_cor_ordre_origine;

}

1;
