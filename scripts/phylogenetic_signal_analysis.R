# ============================================================
# Script: phylogenetic_signal_analysis.R
# Description: Build a phylogenetic tree and compute 
# phylogenetic signals for plant traits related to 
# flammability and herbivory.
# Author: Helena Roland
# ============================================================

# ------------------------
# Load Required Packages
# ------------------------
install.packages(c("V.PhyloMaker", "ape", "picante", "ggtree", "Cairo")) # Run once

library(V.PhyloMaker)
library(ape)
library(picante)
library(ggtree)
library(phylobase)
library(phytools)
library(phylosignal)
library(Cairo)
library(here)
library(writexl)
library(grid)

# ------------------------
# Build the Phylogenetic Tree
# ------------------------
setwd(here::here())

tree_list <- read.table("data/species_list.csv", header = FALSE, sep = ";")

tree.a <- phylo.maker(
  sp.list = tree_list, 
  tree = GBOTB.extended, 
  nodes = nodes.info.1, 
  scenarios = "S3"
)

ape::write.tree(tree.a$scenario.3, file = "tree.txt")

par(mfrow = c(1, 1))
plot.phylo(tree.a$scenario.3, type = "fan", cex = 0.8, main = "Scenario 3")

# ------------------------
# Read and Plot the Tree
# ------------------------
phy <- read.tree("data/tree.txt")
plot(phy)

# ------------------------
# Prepare Trait Data and Calculate Distances
# ------------------------
Kparameter_data <- read.table("data/Kparameter_data.txt", header = TRUE, sep = "\t", row.names = 1)

phy_dist <- cophenetic(phy)

is.rooted(phy)

phy <- multi2di(phy)

traits <- Kparameter_data[phy$tip.label, ]


# ------------------------
# Standardize Species Names
# ------------------------
phy$tip.label <- gsub("_", " ", phy$tip.label)

rownames(traits) <- gsub("_", " ", rownames(traits))

# ------------------------
# Combine Tree and Trait Data
# ------------------------
phylo4 <- phylo4(phy, check.node.labels = c("keep", "drop"))

p4d <- phylo4d(phylo4, traits)

# ------------------------
# Create a phylo4d object
# ------------------------
p4d <- phylo4d(phy, traits)

# ------------------------
# Calculate phylogenetic signal
# ------------------------
tabela_K <- phyloSignal(
  p4d,
  methods = c("all", "I", "Cmean", "Lambda", "K", "K.star"),
  reps = 999,
  W = NULL
)

# Extract results
table_k_VALUES <- as.data.frame(tabela_K$stat)
table_k_P <- as.data.frame(tabela_K$pvalue)

# Export results
write_xlsx(tabela_k_VALUES, path = "outputs/table_k_VALUES.xlsx")
write_xlsx(tabela_k_P, path = "outputs/table_k_P.xlsx")

# ------------------------
# Define green color palette
# ------------------------
green_palette <- colorRampPalette(c("#ffffff", "#006400"))(100)

# ------------------------
# Plot trait values along the phylogeny
# ------------------------
gridplot(p4d, 
         trait = c("LA", "SLA", "LDMC", "RK", "RV", "SDM"), 
         center = TRUE,
         scale = TRUE,
         tree.ladderize = TRUE,
         tree.type = "phylogram",
         tree.ratio = 0.2,
         show.tip = TRUE,
         tip.col = "black",
         tip.cex = 1.1,
         show.color.scale = TRUE,
         show.trait = TRUE,
         trait.cex = 0.7,
         trait.bg.col = "grey90",
         cell.col = green_palette,
         show.box = TRUE,
         grid.vertical = TRUE,
         grid.horizontal = TRUE,
         grid.col = "grey50",
         grid.lty = "dashed")

grid.text("Standardized trait values\n(z-scores)", 
          x = 0.1, y = 0.15, gp = gpar(fontsize = 7.7))

# ------------------------
# Save the plot as a high-resolution PNG file
# ------------------------
