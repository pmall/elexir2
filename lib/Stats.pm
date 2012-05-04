package Stats;
use strict;
use warnings;
use List::Util qw(min);
use List::MoreUtils qw(uniq);
use Exporter qw(import);

our @EXPORT = qw(ttest adjust_pvals);

# ==============================================================================
# Fonction ttest
# ==============================================================================

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

	return $p_value;

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

	for(my $i = 0; $i < @list_cor; $i++){

		my $min = min($list_cor[$i], @list_cor[($i + 1)..$#list_tri]);

		push(@list_cor_ord, $min);

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
