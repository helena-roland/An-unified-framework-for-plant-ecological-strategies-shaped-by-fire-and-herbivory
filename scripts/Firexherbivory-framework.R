

# ============================================================
# 1 part: pcoa_analysis
# Description: Principal Coordinate Analysis (PCoA) 
# on plant trait data related to flammability and herbivory.
# Author: Helena Roland
# ============================================================

# ------------------------
# Load Required Packages
# ------------------------
install.packages(c("vegan", "ape", "writexl"))
library(vegan)
library(ape)
library(writexl)

# ------------------------
# Prepare the Data
# ------------------------

# Load the data from the text file
pcoa_data <- read.table("data/pcoa_data.txt", header = TRUE, sep = "\t", stringsAsFactors = FALSE)

# Keep only numeric columns for dissimilarity calculation
numeric_data <- pcoa_data[sapply(pcoa_data, is.numeric)]

# Create Gower Dissimilarity Matrix
data.D <- vegdist(numeric_data, method = "gower")

# Perform Principal Coordinates Analysis
PCOA_1 <- pcoa(data.D)

# Save coordinates and eigenvalues
write_xlsx(as.data.frame(PCOA_1$vectors), path = "outputs/vectors_pcoa.xlsx")
write_xlsx(as.data.frame(PCOA_1$values), path = "outputs/engeinvalues.xlsx")

# ------------------------
# Plot the PCoA with LF and SpType
# ------------------------

# Ensure 'LF' and 'SpType' are factors
pcoa_data$LF <- as.factor(pcoa_data$LF)
pcoa_data$SpType <- as.factor(pcoa_data$SpType)

# Define colors for Life Forms (LF)
colors <- c("woody" = "#0072B2", "non-woody" = "#D55E00")
point_colors <- colors[as.character(pcoa_data$LF)]
point_colors_alpha <- adjustcolor(point_colors, alpha.f = 0.7)

# Define point shapes: triangles for grass, circles for others
point_shapes <- ifelse(pcoa_data$SpType == "grass", 17, 16)

# Start plotting
dev.new()
plot.new()
plot(
  PCOA_1$vectors[, 1], PCOA_1$vectors[, 2],
  xlab = "Axis 1 = 52%", ylab = "Axis 2 = 31%", 
  main = "Framework: Flammability x Herbivory", 
  pch = point_shapes,
  col = point_colors_alpha,
  cex = 1.6,
  xlim = c(-0.4, 0.6),
  ylim = c(-0.4, 0.4)
)

# Add legend
legend_colors <- adjustcolor(c("#0072B2", "#D55E00", "#D55E00"), alpha.f = 0.7)
legend("topright",
       legend = c("woody", "non-woody", "grass"),
       col = legend_colors,
       pch = c(16, 16, 17),
       bty = "n",
       cex = 1,
       pt.cex = 1.5,
       inset = c(-0.05, -0.04),
       xpd = TRUE,
       y.intersp = 0.5
)

# ------------------------
# Fit Environmental Variables
# ------------------------

# Convert to matrix if needed
numeric_data  <- as.matrix(numeric_data )

# Fit numeric variables to the ordination
env_fit <- envfit(PCOA_1$vectors, numeric_data)

# Extract arrows (loadings)
coords_variables <- env_fit$vectors$arrows

# Scale arrows to fit within plot limits
scale_factor <- min(
  0.5 / max(abs(coords_variables[, 1])),
  0.4 / max(abs(coords_variables[, 2]))
)

# Add arrows
arrows(
  0, 0,
  coords_variables[, 1] * scale_factor,
  coords_variables[, 2] * scale_factor,
  col = "gray30", lwd = 2, length = 0.1
)

# Add variable labels
text(
  coords_variables[, 1] * scale_factor,
  coords_variables[, 2] * scale_factor,
  labels = colnames(numeric_data),
  col = "gray30", pos = 4, cex = 1.3
)

# ------------------------
# Save Final Plot
# ------------------------
dev.print(tiff, filename = "outputs/pcoa-lifeform-grass.tiff",
          width = 8, height = 7, units = "in", res = 600)


# ============================================================
#  2 part:  flammability_regressions
# Description: Linear regression analysis relating PCoA axes 
# and CSR strategies to flammability traits. Includes 
# assumption diagnostics and p-value corrections.
# Author: Helena Roland
# ============================================================

# ------------------------
# Load Required Packages
# ------------------------
library(lmtest)
library(car)
library(dplyr)

# ------------------------
# Load Data
# ------------------------
regression_data <- read.table("data/regression_data.txt", header = TRUE, row.names = 1, sep = "\t")

# ------------------------
# Data Preparation
# ------------------------
regression_data$FMC_ig_log <- log(regression_data$FMC_ig + 1)

# ------------------------
# Define Models
# ------------------------
models <- list(
  MCR_Axis1      = MCR ~ Axis_1,
  MCR_Axis2      = MCR ~ Axis_2,
  BP_Axis1       = BP ~ Axis_1,
  BP_Axis2       = BP ~ Axis_2,
  FMCig_Axis1    = FMC_ig ~ Axis_1,
  FMCig_Axis2    = FMC_ig_log ~ Axis_2,
  MCR_R          = MCR ~ R,
  BP_R           = BP ~ R,
  FMCig_R        = FMC_ig ~ R
)

# ------------------------
# Run Models and Diagnostics
# ------------------------
run_model <- function(formula, data) {
  model <- lm(formula, data = data)
  list(
    model = model,
    shapiro_p = shapiro.test(resid(model))$p.value,
    bptest_p = bptest(model)$p.value,
    dw_p = durbinWatsonTest(model)$p,
    p_value = summary(model)$coefficients[2, 4],
    r_squared = summary(model)$r.squared
  )
}

results <- lapply(models, run_model, data = regression_data)

# ------------------------
# Multiple Testing Correction
# ------------------------
p_values <- sapply(results, function(x) x$p_value)

p_adjusted <- data.frame(
  Model = names(models),
  Original_p = p_values,
  Bonferroni = p.adjust(p_values, method = "bonferroni"),
  Holm = p.adjust(p_values, method = "holm"),
  FDR = p.adjust(p_values, method = "fdr")
)

# ------------------------
# Diagnostics Summary and Export
# ------------------------
diagnostics <- data.frame(
  Model = names(models),
  Shapiro_Wilk_p = sapply(results, function(x) x$shapiro_p),
  Breusch_Pagan_p = sapply(results, function(x) x$bptest_p),
  Durbin_Watson_p = sapply(results, function(x) x$dw_p),
  R_squared = sapply(results, function(x) round(x$r_squared, 3)),
  Model_p_value = p_values  # substitua 'model_p' pelo nome correto
)

# Export diagnostics summary to CSV inside outputs folder
write.csv(diagnostics, "outputs/regression_diagnostics.csv", row.names = FALSE)

# Optionally, print in console too
print(diagnostics, row.names = FALSE)
