# On récupère les paramètres
out_dir		= commandArgs()[4];
prefixe		= commandArgs()[5];
img_width	= commandArgs()[6];
img_height	= commandArgs()[7];

# ==============================================================================
# ON RECUPERE LES DATAS
# ==============================================================================

# On lit les datas
data_qc = read.table(paste(out_dir, '/', prefixe, '.report.txt', sep = ''), header = TRUE);
data_sum = read.table(paste(out_dir, '/', prefixe, '.summary.txt', sep = ''), header = TRUE);

# On pécho le nombre de puces
nb_puces = dim(data_qc)[1];

# On vire la première colone des intensités
data_sum = data_sum[, 2:(nb_puces + 1)];

# On met a jour les noms des puces
names(data_sum) = seq(1, nb_puces);

# ==============================================================================
# AUC + Raw Intensities
# ==============================================================================

# On enregistre le auc
png(paste(out_dir, '/', 'pos_vs_neg_auc.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(data_qc$pos_vs_neg_auc, type = 'b', main = 'pos vs neg AUC', xlab = 'Chips', ylab = 'Area under the ROC curve', ylim = c(0.5, 1), col = c('red'), xaxt = 'n');
abline(h = 0.8, lty = 2, col = c('red'));
axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));
legend(1, 0.6, c('pos vs neg auc', 'limit'), col = c('red', 'red'), lty = c(1, 2));

dev.off();

# Intensités brutes
png(paste(out_dir, '/', 'raw_intensities.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

moyenne = mean(c(data_qc$pm_mean, data_qc$bgrd_mean));
max = max(data_qc$pm_mean, data_qc$bgrd_mean);
min = min(data_qc$pm_mean, data_qc$bgrd_mean);
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));

plot(data_qc$pm_mean, type = 'b', main = 'Raw Intensity', xlab = 'Chips', ylab = 'Raw intensity', ylim = c(bot, top), col = c('red'), xaxt = 'n');
lines(data_qc$bgrd_mean, type = 'b', col = c('blue'));
axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));
legend(1, top, c('perfect match', 'background'), col = c('red', 'blue'), lty = 1);

dev.off();

# ==============================================================================
# Toutes les metrixs sur le all probeset
# ==============================================================================

# All probeset mean
png(paste(out_dir, '/', 'all_probeset_mean.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

moyenne = mean(data_qc$all_probeset_mean);
max = max(data_qc$all_probeset_mean);
min = min(data_qc$all_probeset_mean);
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));

plot(data_qc$all_probeset_mean, type = 'b', main = 'All probeset mean', xlab = 'Chips', ylab = 'Intensity', ylim = c(bot, top), col = c('red'), xaxt = 'n');
axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));
legend(1, top, c('mean'), col = c('red', 'blue', 'green', 'orange'), lty = 1);

dev.off();

# All probeset mad_residual_mean rle_mean
png(paste(out_dir, '/', 'all_probeset_mad_rle.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

moyenne = mean(c(data_qc$all_probeset_mad_residual_mean, data_qc$all_probeset_rle_mean));
max = max(data_qc$all_probeset_mad_residual_mean, data_qc$all_probeset_rle_mean);
min = min(data_qc$all_probeset_mad_residual_mean, data_qc$all_probeset_rle_mean);
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));

plot(data_qc$all_probeset_mad_residual_mean, type = 'b', main = 'All probeset mad residual mean and rle mean', xlab = 'Chips', ylab = 'mean', ylim = c(bot, top + 0.1), col = c('blue'), xaxt = 'n');
lines(data_qc$all_probeset_rle_mean, type = 'b', col = c('green'));
axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));
legend(1, top + 0.1, c('mad residual', 'rle'), col = c('blue', 'green'), lty = 1);

dev.off();

# ==============================================================================
# Controle des valeurs du mad residual mean et du rle
# ==============================================================================

# Controle mad residual mean
png(paste(out_dir, '/', 'mad_residual_mean_controle.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

bac_spike_mean = mean(data_qc$bac_spike_mad_residual_mean);
bac_spike_sd = sd(data_qc$bac_spike_mad_residual_mean);
bac_spike_top_lim = bac_spike_mean + 2 * bac_spike_sd;
bac_spike_bot_lim = bac_spike_mean - 2 * bac_spike_sd;

polya_spike_mean = mean(data_qc$polya_spike_mad_residual_mean);
polya_spike_sd = sd(data_qc$polya_spike_mad_residual_mean);
polya_spike_top_lim = polya_spike_mean + 2 * polya_spike_sd;
polya_spike_bot_lim = polya_spike_mean - 2 * polya_spike_sd;

pos_control_mean = mean(data_qc$pos_control_mad_residual_mean);
pos_control_sd = sd(data_qc$pos_control_mad_residual_mean);
pos_control_top_lim = pos_control_mean + 2 * pos_control_sd;
pos_control_bot_lim = pos_control_mean - 2 * pos_control_sd;

max = max(bac_spike_top_lim, polya_spike_top_lim, pos_control_top_lim);
min = min(bac_spike_bot_lim, polya_spike_bot_lim, pos_control_bot_lim);
moyenne = mean(c(max, min));
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));

plot(data_qc$bac_spike_mad_residual_mean, type = 'b', main = 'MAD residual mean', xlab = 'Chips', ylab = 'MAD residual mean', ylim = c(bot, top + 0.2), col = c('blue'), xaxt = 'n');
abline(h = bac_spike_top_lim, lty = 2, col = c('blue'));
abline(h = bac_spike_bot_lim, lty = 2, col = c('blue'));

lines(data_qc$polya_spike_mad_residual_mean, type = 'b', col = c('green'));
abline(h = polya_spike_top_lim, lty = 2, col = c('green'));
abline(h = polya_spike_bot_lim, lty = 2, col = c('green'));

lines(data_qc$pos_control_mad_residual_mean, type = 'b', col = c('orange'));
abline(h = pos_control_top_lim, lty = 2, col = c('orange'));
abline(h = pos_control_bot_lim, lty = 2, col = c('orange'));

axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));

legend(1, top + 0.2, c('bac spike', 'polya spike', 'pos control'), col = c('blue', 'green', 'orange'), lty = 1);

dev.off();

# Controle rel mean
png(paste(out_dir, '/', 'rle_mean_controle.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

bac_spike_mean = mean(data_qc$bac_spike_rle_mean);
bac_spike_sd = sd(data_qc$bac_spike_rle_mean);
bac_spike_top_lim = bac_spike_mean + 2 * bac_spike_sd;
bac_spike_bot_lim = bac_spike_mean - 2 * bac_spike_sd;

polya_spike_mean = mean(data_qc$polya_spike_rle_mean);
polya_spike_sd = sd(data_qc$polya_spike_rle_mean);
polya_spike_top_lim = polya_spike_mean + 2 * polya_spike_sd;
polya_spike_bot_lim = polya_spike_mean - 2 * polya_spike_sd;

pos_control_mean = mean(data_qc$pos_control_rle_mean);
pos_control_sd = sd(data_qc$pos_control_rle_mean);
pos_control_top_lim = pos_control_mean + 2 * pos_control_sd;
pos_control_bot_lim = pos_control_mean - 2 * pos_control_sd;

max = max(bac_spike_top_lim, polya_spike_top_lim, pos_control_top_lim);
min = min(bac_spike_bot_lim, polya_spike_bot_lim, pos_control_bot_lim);
moyenne = mean(c(max, min));
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));

plot(data_qc$bac_spike_rle_mean, type = 'b', main = 'RLE mean', xlab = 'Chips', ylab = 'RLE mean', ylim = c(bot, top + 0.2), col = c('blue'), xaxt = 'n');
abline(h = bac_spike_top_lim, lty = 2, col = c('blue'));
abline(h = bac_spike_bot_lim, lty = 2, col = c('blue'));

lines(data_qc$polya_spike_rle_mean, type = 'b', col = c('green'));
abline(h = polya_spike_top_lim, lty = 2, col = c('green'));
abline(h = polya_spike_bot_lim, lty = 2, col = c('green'));

lines(data_qc$pos_control_rle_mean, type = 'b', col = c('orange'));
abline(h = pos_control_top_lim, lty = 2, col = c('orange'));
abline(h = pos_control_bot_lim, lty = 2, col = c('orange'));

axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));

legend(1, top + 0.2, c('bac spike', 'polya spike', 'pos control'), col = c('blue', 'green', 'orange'), lty = 1);

dev.off();

# ==============================================================================
# Metrixs sur les controles
# ==============================================================================

# Bac spike 5' !

biob = data_qc$bac_spike.AFFX.r2.Ec.bioB.5_at;
bioc = data_qc$bac_spike.AFFX.r2.Ec.bioC.5_at;
biod = data_qc$bac_spike.AFFX.r2.Ec.bioD.5_at;
cre = data_qc$bac_spike.AFFX.r2.P1.cre.5_at;

moyenne = mean(c(biob, bioc, biod, cre));
max = max(c(biob, bioc, biod, cre));
min = min(c(biob, bioc, biod, cre));
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));
colors = rainbow(nb_puces);

png(paste(out_dir, '/', 'bac_spike_ordre_5_1.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(cre, type = 'b', main = 'Hybridization quality control 5\' 1', xlab = 'Chips', ylab = 'Intensity for each bacterial control', ylim = c(bot, top + 1), col = c('red'), xaxt = 'n');
lines(biod, type = 'b', col = c('blue'));
lines(bioc, type = 'b', col = c('green'));
lines(biob, type = 'b', col = c('orange'));
axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));
legend(1, top + 1, c('Cre', 'bioD', 'bioC', 'bioB'), col = c('red', 'blue', 'green', 'orange'), lty = 1);

dev.off();

png(paste(out_dir, '/', 'bac_spike_ordre_5_2.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(c(biob[1], bioc[1], biod[1], cre[1]), type = 'l', main = 'Hybridization quality control 5\' 2', xlab = 'Bacterial controls', ylab = 'Intensity for each chip', xlim = c(1, 4) , ylim = c(min, max), col = colors[1], xaxt='n');

for(i in seq(2, nb_puces)){
	lines(c(biob[i], bioc[i], biod[i], cre[i]), type = 'l', col = colors[i]);
}

axis(side = 1, labels = c('bioB', 'bioC', 'bioD', 'cre'), at = c(1, 2, 3, 4));
legend(1, max(biob, bioc, biod, cre), seq(nb_puces), col = colors, lty = 1);

dev.off();

# Bac spike 3' !

biob = data_qc$bac_spike.AFFX.r2.Ec.bioB.3_at;
bioc = data_qc$bac_spike.AFFX.r2.Ec.bioC.3_at;
biod = data_qc$bac_spike.AFFX.r2.Ec.bioD.3_at;
cre = data_qc$bac_spike.AFFX.r2.P1.cre.3_at;

moyenne = mean(c(biob, bioc, biod, cre));
max = max(c(biob, bioc, biod, cre));
min = min(c(biob, bioc, biod, cre));
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));
colors = rainbow(nb_puces);

png(paste(out_dir, '/', 'bac_spike_ordre_3_1.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(cre, type = 'b', main = 'Hybridization quality control 3\' 1', xlab = 'Chips', ylab = 'Intensity for each bacterial control', ylim = c(bot, top + 1), col = c('red'), xaxt = 'n');
lines(biod, type = 'b', col = c('blue'));
lines(bioc, type = 'b', col = c('green'));
lines(biob, type = 'b', col = c('orange'));
axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));
legend(1, top + 1, c('Cre', 'bioD', 'bioC', 'bioB'), col = c('red', 'blue', 'green', 'orange'), lty = 1);

dev.off();

png(paste(out_dir, '/', 'bac_spike_ordre_3_2.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(c(biob[1], bioc[1], biod[1], cre[1]), type = 'l', main = 'Hybridization quality control 3\' 2', xlab = 'Bacterial controls', ylab = 'Intensity for each chip', xlim = c(1, 4) , ylim = c(min, max), col = colors[1], xaxt='n');

for(i in seq(2, nb_puces)){
	lines(c(biob[i], bioc[i], biod[i], cre[i]), type = 'l', col = colors[i]);
}

axis(side = 1, labels = c('bioB', 'bioC', 'bioD', 'cre'), at = c(1, 2, 3, 4));
legend(1, max(biob, bioc, biod, cre), seq(nb_puces), col = colors, lty = 1);

dev.off();

# polya spikes 5'

lys = data_qc$polya_spike.AFFX.r2.Bs.lys.5_st;
phe = data_qc$polya_spike.AFFX.r2.Bs.phe.5_st;
thr = data_qc$polya_spike.AFFX.r2.Bs.thr.5_s_st;
dap = data_qc$polya_spike.AFFX.r2.Bs.dap.5_st;

moyenne	= mean(c(thr, phe, lys, dap));
max = max(c(thr, phe, lys, dap));
min = min(c(thr, phe, lys, dap));
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));
colors = rainbow(nb_puces);

png(paste(out_dir, '/', 'polya_spike_ordre_5_1.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(dap, type = 'b', main = 'Labeling quality control 5\' 1', xlab = 'Chips', ylab = 'Intensity for each polyA control RNA', ylim = c(bot, top + 1), col = c('red'), xaxt = 'n');
lines(thr, type = 'b', col = c('blue'));
lines(phe, type = 'b', col = c('green'));
lines(lys, type = 'b', col = c('orange'));
axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));
legend(1, top + 1, c('Dap', 'Thr', 'Phe', 'Lys'), col = c('red', 'blue', 'green', 'orange'), lty = 1);

dev.off();

png(paste(out_dir, '/', 'polya_spike_ordre_5_2.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(c(lys[1], phe[1], thr[1], dap[1]), type = 'l', main = 'Labeling quality control 5\' 2', xlab = 'PolyA control RNA', ylab = 'Intensity for each chip', xlim = c(1, 4), ylim = c(min, max), col = colors[1], xaxt = 'n');

for(i in seq(2, nb_puces)){
	lines(c(lys[i], phe[i], thr[i], dap[i]), type = 'l', col = colors[i]);
}

axis(side = 1, labels = c('lys', 'phe', 'thr', 'dap'), at = c(1, 2, 3, 4));
legend(1, max(lys, phe, thr, dap), seq(nb_puces), col = colors, lty = 1);

dev.off();

# polya spikes M

lys = data_qc$polya_spike.AFFX.r2.Bs.lys.M_st;
phe = data_qc$polya_spike.AFFX.r2.Bs.phe.M_st;
thr = data_qc$polya_spike.AFFX.r2.Bs.thr.M_s_st;
dap = data_qc$polya_spike.AFFX.r2.Bs.dap.M_st;

moyenne	= mean(c(thr, phe, lys, dap));
max = max(c(thr, phe, lys, dap));
min = min(c(thr, phe, lys, dap));
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));
colors = rainbow(nb_puces);

png(paste(out_dir, '/', 'polya_spike_ordre_M_1.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(dap, type = 'b', main = 'Labeling quality control M 1', xlab = 'Chips', ylab = 'Intensity for each polyA control RNA', ylim = c(bot, top + 1), col = c('red'), xaxt = 'n');
lines(thr, type = 'b', col = c('blue'));
lines(phe, type = 'b', col = c('green'));
lines(lys, type = 'b', col = c('orange'));
axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));
legend(1, top + 1, c('Dap', 'Thr', 'Phe', 'Lys'), col = c('red', 'blue', 'green', 'orange'), lty = 1);

dev.off();

png(paste(out_dir, '/', 'polya_spike_ordre_M_2.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(c(lys[1], phe[1], thr[1], dap[1]), type = 'l', main = 'Labeling quality control M 2', xlab = 'PolyA control RNA', ylab = 'Intensity for each chip', xlim = c(1, 4), ylim = c(min, max), col = colors[1], xaxt = 'n');

for(i in seq(2, nb_puces)){
	lines(c(lys[i], phe[i], thr[i], dap[i]), type = 'l', col = colors[i]);
}

axis(side = 1, labels = c('lys', 'phe', 'thr', 'dap'), at = c(1, 2, 3, 4));
legend(1, max(lys, phe, thr, dap), seq(nb_puces), col = colors, lty = 1);

dev.off();

# polya spikes 3'

lys = data_qc$polya_spike.AFFX.r2.Bs.lys.3_st;
phe = data_qc$polya_spike.AFFX.r2.Bs.phe.3_st;
thr = data_qc$polya_spike.AFFX.r2.Bs.thr.3_s_st;
dap = data_qc$polya_spike.AFFX.r2.Bs.dap.3_st;

moyenne	= mean(c(thr, phe, lys, dap));
max = max(c(thr, phe, lys, dap));
min = min(c(thr, phe, lys, dap));
top = max + (moyenne/2);
bot = max(0, min - (moyenne/2));
colors = rainbow(nb_puces);

png(paste(out_dir, '/', 'polya_spike_ordre_3_1.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(dap, type = 'b', main = 'Labeling quality control 3\' 1', xlab = 'Chips', ylab = 'Intensity for each polyA control RNA', ylim = c(bot, top + 1), col = c('red'), xaxt = 'n');
lines(thr, type = 'b', col = c('blue'));
lines(phe, type = 'b', col = c('green'));
lines(lys, type = 'b', col = c('orange'));
axis(side = 1, labels = seq(1, nb_puces), at = seq(1, nb_puces));
legend(1, top + 1, c('Dap', 'Thr', 'Phe', 'Lys'), col = c('red', 'blue', 'green', 'orange'), lty = 1);

dev.off();

png(paste(out_dir, '/', 'polya_spike_ordre_3_2.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

plot(c(lys[1], phe[1], thr[1], dap[1]), type = 'l', main = 'Labeling quality control 3\' 2', xlab = 'PolyA control RNA', ylab = 'Intensity for each chip', xlim = c(1, 4), ylim = c(min, max), col = colors[1], xaxt = 'n');

for(i in seq(2, nb_puces)){
	lines(c(lys[i], phe[i], thr[i], dap[i]), type = 'l', col = colors[i]);
}

axis(side = 1, labels = c('lys', 'phe', 'thr', 'dap'), at = c(1, 2, 3, 4));
legend(1, max(lys, phe, thr, dap), seq(nb_puces), col = colors, lty = 1);

dev.off();

# ==============================================================================
# Boxplot RLE
# ==============================================================================

png(paste(out_dir, '/', 'all_probeset_rle_boxplot.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

medians = apply(data_sum, 1, median);
rle = data_sum - medians;

boxplot(rle, xlim = c(1, nb_puces), main = 'Boxplot RLE');

dev.off();

# ==============================================================================
# PRINCIPAL COMPONENT ANALYSIS
# ==============================================================================

# On inclu la librairie pca
library(ade4);

# On fait la pca
# pca = dudi.pca(data_sum, scannf = FALSE, nf = 3, scale = FALSE);
pca = dudi.pca(data_sum, scannf = FALSE, nf = 2, scale = FALSE);

# On ouvre le fichier png
png(paste(out_dir, '/', 'pca.png', sep = ''), width = as.integer(img_width), height = as.integer(img_height));

# On calcule le max et le min
max = max(pca$co[,2]);
min = min(pca$co[,2]);

# On trace la pca
s.arrow(pca$co, ylim = c(min, max));

# On enregistre l'image
dev.off();
