package Stats;
use strict;
use warnings;
use List::Util qw(min);
use List::MoreUtils qw(uniq);
use Statistics::Distributions;
use lib $FindBin::Bin;
use Math;
use Exporter qw(import);

our @EXPORT = qw(ttest adjust_pvals);

# ==============================================================================
# Fonction ttest
# ==============================================================================

=head
# Effectue un ttest à partir d'une valeur moyenne/mediane/whatever et de la
# liste des échantillons qui a permi de calculer cette valeur
sub ttest{

	my($R, $value, @samples) = @_;

	# Si toutes les valeurs des samples sont identique, on en incrémente 1
	# de 0.01 (sinon R ne veut pas faire le test)
	if(uniq(@samples) == 1){ $samples[0]+= 0.01; }

	# On initialise les variables pour le test
	my $mu = 0;
	my $alternative = ($value > 0) ? "greater" : "less";

	# On calcule la p_value avec R
	$R->send('x <- c(' . join(', ', @samples) . ');');
	$R->send('test<-t.test(x, mu=' . $mu . ', alternative="' . $alternative . '"); print(1);');
	$R->send('print(test$p.value);');
	my $out = $R->read;
	my @outs = split(/ /, $out);
	my $p_value = $outs[1];

	# On clean les objets de R
	$R->clean_up;

	return $p_value;

}
=cut

# Effectue un ttest à partir d'une valeur moyenne/mediane/whatever et de la
# liste des échantillons qui a permi de calculer cette valeur
sub ttest{

	my($value, @samples) = @_;

	# Si tout les fc sont identiques on bouge le premier de 0.01
	# sinon sd(@samples) = 0 et erreur
	if(uniq(@samples) == 1){ $samples[0]+= 0.01; }

	# On calcule t valeur de notre sample
	my $t = mean(@samples)/(sd_est(@samples)/(@samples**0.5));

	# On recherche la valeur critique (degré de liberté : N - 1)
	my $t_prob = Statistics::Distributions::tprob(@samples - 1, $t);

	# Si on compare a une valeur négative, il faut 1 - $t_prob
	if($value < 0){ $t_prob = 1 - $t_prob; }

	# On retourne la p value
	return $t_prob;

}

# ==============================================================================
# Fonction correction pvalues
# ==============================================================================

sub adjust_pvals{

	my ($list) = @_;

	my @list = @{$list};

	# On classe les pvalues (définies) dans l'ordre croissant
	my @list_tri = (sort {$a <=> $b} (grep { defined $_ } @list));

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

	foreach my $val (@list){

		my $val_cor = (defined $val) ? $h_pval_pvalcor{$val} : undef;

		push(@list_cor_ordre_origine, $val_cor);

	}

	# On retourne la liste dans le bon ordre
	return @list_cor_ordre_origine;

}

1;
