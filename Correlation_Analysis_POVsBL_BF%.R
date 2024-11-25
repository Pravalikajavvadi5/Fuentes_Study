
##------ Correlation Analysis of Change in Gene Expression Vs Bodyfat Percentage at Baseline ------##

library(readr)
library(ppcor)
library(dplyr)
library(ggplot2)
library(reshape2)
library(readr)
library(writexl)
library(tidyr)
library(VennDiagram)
library(ggpubr)

norm_counts <- read.csv("output_voom_norm_counts_POVsBL.csv", header = T, stringsAsFactors = F) ##log2-transformed normalized gene expression counts (POVsBL_ALL)
genes <- read.csv("output_POVsBL_genes.csv", header = T, stringsAsFactors = F) #Load the gene symbols data 
Subject_ID <- read.csv("output_POVsBL_PatientIDs.csv", header = T, stringsAsFactors = F) #Load the Patient ID data
Sample_data <- read.csv("New_Sample_Data_Fuentes_Study.csv", header = T, stringsAsFactors = F) #Load the sample information


# replace column name for subject id
names(Subject_ID)[names(Subject_ID) == "x"] <- "Subject_ID"

#Convert the Subject_ID column to a factor with unique levels for each subject
Subject <- factor(Subject_ID$Subject_ID, levels = unique(Subject_ID$Subject_ID))

# initialize an empty matrix to store log2fc values
log2FC_matrix <- matrix(NA, nrow = nrow(norm_counts), ncol = length(Subject)/2)

# Add row and column names to the log2FC_matrix
rownames(log2FC_matrix) <- genes$gene  # Gene names
colnames(log2FC_matrix) <- levels(Subject)

# Here, we're calculating the log2fc for each gene between the two time points for each individual sample pair
for (i in 1:ncol(log2FC_matrix)) {
  # Calculate the column indices in norm_counts
  before_index <- 2 * i - 1
  after_index <- 2 * i
  
  # Compute log2 fold change for each pair of BL and PO samples
  log2FC_matrix[, i] <- norm_counts[, after_index] - norm_counts[, before_index]
}

## tranpose the matrix so that genes will be columns and samples as rows
log2FC_matrix <- t(log2FC_matrix)

# Get the phenotype (Bodyfat percent at baseline) data from our sample data
Fat_mass_percent_basal <- data.frame(Sample_ID = Sample_data$Transcript_ID, Fat_mass_percent_basal = Sample_data$Fat_mass_percent_basal, Group_Cost_Weight_Gain = Sample_data$Group_Cost_Weight_Gain)
Fat_mass_percent_basal$Group_Cost_Weight_Gain <- gsub("LOW_", "LOW", Fat_mass_percent_basal$Group_Cost_Weight_Gain)
Fat_mass_percent_basal <- Fat_mass_percent_basal[-11,] #remove the 11th column because it's an outlier data
rownames(Fat_mass_percent_basal)[rownames(Fat_mass_percent_basal) == "12"] <- "11"  #re- arrange the rownames 


# Create a new column with matched values from Fat_mass_percent_basal df to the log2FC_matrix

# Find the matching indices for rownames of log2FC_matrix in Fat_mass_percent_basal$Sample_ID
match_indices <- match(rownames(log2FC_matrix), Fat_mass_percent_basal$Sample_ID)

# Add the corresponding value from fat_mass_percent_basal df as a new column to log2FC_matrix
pcor_data <- cbind(log2FC_matrix, Fat_mass_percent_basal$Fat_mass_percent_basal[match_indices])

# Assign a name to the new column added from pcor_data
colnames(pcor_data)[ncol(pcor_data)] <- "Fat_mass_percent_basal"


##----------------------------------------------Partial Correlation Analysis------------------------------------------------------------##

# Get the number of columns in the matrix (excluding Fat_mass_percent_basal, which is the last column)
num_genes <- ncol(pcor_data) - 1

# Initialize vectors to store the partial correlations and p-values
pcor_values <- numeric(num_genes)
p_values <- numeric(num_genes)

# Perform partial correlation of each gene's expression value across rows with fat_mass_percent_basal
for (i in 1:num_genes) {
  # Extract the gene data as a vector
  gene_data <- pcor_data[, i]
  
  # Combine the gene data and fat_mass_percent_basal into a temporary matrix for correlation
  data_combined <- cbind(gene_data, pcor_data[, "Fat_mass_percent_basal"])
  
  # Compute partial correlation between the gene and fat_mass_percent_basal
  pcor_test <- pcor(data_combined)
  
  # Store partial correlation and p-value for this gene
  pcor_values[i] <- pcor_test$estimate[1, 2]
  p_values[i] <- pcor_test$p.value[1, 2]
}

# Create a data frame for the partial correlation results
pcorr_results <- data.frame(
  Gene = colnames(pcor_data)[1:num_genes],
  P_Correlation = pcor_values,
  P_values = p_values
)

# View the results
print(pcorr_results)

# Add a column to classify correlations as positive or negative based on Partial Correlation values and significance level (P_values < 0.05)
pcorr_results$Correlation <- ifelse(pcorr_results$P_Correlation > 0 & pcorr_results$P_values < 0.05, "Positive_Correlation", "Negative_Correlation")
#write_xlsx(pcorr_results, "P_Correlation_Results_POVsBL_Vs_BFpercent.xlsx")

## subset the positively correlated genes that have statistically significant p-values
high_corr <- pcorr_results %>%
  filter(P_Correlation > 0 & P_values < 0.05)

high_corr <- high_corr[order(-high_corr$P_Correlation),] #sort the positively correlated genes by P_correlation values
#write_xlsx(high_corr, "PositiveCorrelations_POVsBL_Vs_BFpercent.xlsx")

## Positively correlated gene to fat_mass_percent_basal
high_corr[which.max(high_corr$P_Correlation), ]

## Results
# Gene P_Correlation   P_values
# NID1  0.9216966    5.495552e-05

## subset the negatively correlated genes that have statistically significant p-values
low_corr <- pcorr_results %>%
  filter(P_Correlation < 0 & P_values <0.05)

low_corr <- low_corr[order(low_corr$P_Correlation),] #sort the negatively correlated genes by P_correlation values
#write_xlsx(low_corr,"NegativeCorrelations_POVsBL_Vs_BFpercent.xlsx")

## Negatively correlated gene to fat_mass_percent_basal
low_corr[which.min(low_corr$P_Correlation), ]

##Results
#Gene  P_Correlation    P_values
#BORA   -0.8714109     0.000475219

## Gene with the weakest correlation (closest to zero)
low_corr[which.min(abs(low_corr$P_Correlation)),]

## Results
#Gene    P_Correlation   P_values
#MCRIP1   -0.6021646    0.04995388

##------------------------------------------------ Correlation Plot : Gene Vs Partial correlation ---------------------------------------------------##

# Select the top 50 significant genes by arranging in ascending order of p-values
top_50 <- pcorr_results %>%
  arrange(p_values) %>%
  head(50)

#jpeg("Barplot_top50genes_POVsBL_Vs_BFpercent.jpeg", width = 2500, height = 1800, res = 300)

# Bar plot of top 50 correlations 
ggplot(top_50, aes(x = reorder(Gene, P_Correlation), y = P_Correlation, fill = P_Correlation)) +
  geom_bar(stat = "identity") +
  geom_text(aes(label = round(P_values, 4), y = P_Correlation/2),  # Add p-values as labels
            vjust = 0.5,   
            size = 3) +     
  coord_flip() + 
  scale_fill_gradient2(low = "lightblue", high = "salmon", midpoint = 0) +  # Color gradient
  labs(title = "Top 50 Genes: Partial Correlation
         (POVsBL Vs BF% at Baseline)",
       x = "Gene",
       y = "Partial Correlation") +
  theme_minimal()

#dev.off()

##---------------------Correlation Plot - Change in Gene Expression (POVsBL) Vs Bodyfat Percent at Baseline -----------------------------------------------------------------------------------

# filter significant genes based on p-values< 0.05
significant_genes <- pcorr_results[pcorr_results$P_values < 0.05,]

#sig_genes <- data.frame(Gene = significant_genes$Gene)
#write_xlsx(sig_genes, "Sig_GeneList_POVsBL_Vs_BFpercent.xlsx")

# filter the top 50 significant genes by arranging in ascending order of p-values
top_50_genes <- significant_genes %>%
  arrange(P_values) %>%
  head(50)

top50_genes_names <- top_50_genes$Gene # extract the gene names of the top 50 genes

top50_gene_expression_data <- pcor_data[, top50_genes_names]  # extract the gene expression data of the top 50 genes from pcor_data

# Merge the sample, phenotype (BFpercent), and gene expression data into a single data frame
merged_data <- data.frame(
  Sample = rownames(pcor_data),
  BF_percent = pcor_data[, "Fat_mass_percent_basal"],
  top50_gene_expression_data
)

# Reshape the merged data into long format for correlation plotting
cor_plot_data <- melt(merged_data, id.vars = c("Sample", "BF_percent"), variable.name = "Gene", value.name = "Gene_Expression")

#  Add correlation data from the top 50 genes by matching gene names
cor_plot_data <- merge(cor_plot_data, top_50_genes, by.x = "Gene", by.y = "Gene")

#Join additional phenotype data from Fat_mass_percent_basal using sample identifiers
cor_plot_data <- cor_plot_data %>%
  left_join(Fat_mass_percent_basal, by = c("Sample" = "Sample_ID"))

# Remove duplicate Fat_mass_percent_basal column from the merged data
cor_plot_data <- cor_plot_data %>% select(-Fat_mass_percent_basal)


## create a scatterplot btwn change in gene expression (POVsBL) vs bodyfat percent at baseline

#jpeg("Scatterplot_POVsBL_Vs_BF_percent.jpeg", width = 5000, height = 3000, res = 300)

## This scatterplot shows subplots for each gene, so that each plot shows how the gene correlates with the phenotype across all the samples
ggplot(cor_plot_data, aes(x = Gene_Expression, y = BF_percent)) +
  geom_point(aes(color = Group_Cost_Weight_Gain), shape = 16, size = 3) +  
  geom_smooth(method = "lm", se = FALSE, color = "gray70", linetype = "dashed") + 
  stat_cor(aes(label = paste0("r = ", round(after_stat(r), 2))),
           label.x = 0, label.y = max(cor_plot_data$BF_percent) * 1.1,
           hjust = 0.5, size = 4) +  # Center horizontally
  scale_color_manual(values = c("red", "blue")) +
  facet_wrap(~ Gene, scales = "free_x", ncol = 10) +  
  labs(title = "Top 50 Significant Genes: POVsBL Vs Bodyfat percent at baseline",
       x = "Gene Expression", y = "Bodyfat percent at baseline (Phenotype)",
       color = "Groups") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),  # Rotate x-axis labels
        strip.text = element_text(size = 10),  # Increase gene label size in facets
        panel.spacing = unit(1, "lines"))  # Increase space between facets

#dev.off()

##-----------------------------------------------Significant genes Pathways - Enrichr ---------------------------------------##

# Load the Hallmark, Wiki and KEGG pathways data from Enrichr
hallmark <- read_delim("MSigDB_Hallmark_2020_table.txt", delim = '\t')
Wiki <- read_delim("WikiPathways_2024_Human_table.txt", delim = "\t")
Kegg <- read_delim("KEGG_2021_Human_table.txt", delim = "\t")

#write_xlsx(hallmark, "HallmarkPathway_Cor_sigGenes_POVsBL_Vs_BFpercent.xlsx")
#write_xlsx(Wiki, "WikiPathway_Cor_sigGenes_POVsBL_Vs_BFpercent.xlsx")
#write_xlsx(Kegg, "KEGGPathway_Cor_sigGenes_POVsBL_Vs_BFpercent.xlsx")

#Filter Hallmark pathways with P-values less than 0.01
hallmark_Pval_0.01 <- hallmark %>% filter(P-value < 0.01)

#Filter wiki pathways with P-values less than 0.01
wiki_Pval_0.01 <- wiki %>% filter(P-value < 0.01)

#Filter kegg pathways with P-values less than 0.01
kegg_Pval_0.01 <- kegg %>% filter(P-value < 0.01)


#Plot the filtered hallmark pathways 
ggplot(hallmark_Pval_0.01) +
  geom_col(aes(
    x = reorder(Term, Odds_Ratio),
    y = Odds_Ratio,
    fill = -log10(pvalue)
  ), color = "black") +
  scale_fill_distiller(palette = "Greens", direction = 1) +
  coord_flip() +
  theme(
    axis.title = element_text(
      size = 10,
      face = "bold",
      color = "black"
    ),
    axis.text = element_text(size = 8, color = "black"),
    strip.text = element_text(
      size = 9,
      color = "black",
      face = "bold"
    ),
    panel.background = element_rect(fill = "white"),
    legend.position = "bottom",
    axis.line.x = element_line(color="gray30", linetype = "solid")
  ) +
  labs(y = "Odds Ratio", 
       x = "Pathways", 
       title = "HallmarkPathway - POvsBL vs BFpercent (P_Value < 0.01)",
       fill = "-log10(p-value)")  


#Plot the filtered wiki pathways 
ggplot(wiki_Pval_0.01) +
  geom_col(aes(
    x =reorder(Term, Odds_Ratio),
    y =  Odds_Ratio ,
    fill = -log10(pvalue)
  ), color = "black") +
  scale_fill_distiller(palette = "Greens", direction = 1) +
  coord_flip() +
  theme(
    axis.title = element_text(
      size = 10,
      face = "bold",
      color = "black"
    ),
    axis.text = element_text(size = 8, color = "black"),
    strip.text = element_text(
      size = 9,
      color = "black",
      face = "bold"
    ),
    panel.background = element_rect(fill = "white"),
    legend.position = "bottom",
    axis.line.x = element_line(color="gray30", linetype = "solid")
  ) +
  labs(y = "Odds Ratio", 
       x = "Pathways", 
       title = "WikiPathway - POvsBL vs BFpercent (P_Value < 0.01)",
       fill = "-log10(p-value)")  

#Plot the filtered KEGG pathways 
ggplot(kegg_Pval_0.01) +
  geom_col(aes(
    x = reorder(Term, Odds_Ratio),
    y = Odds_Ratio,
    fill = -log10(pvalue)
  ), color = "black") +
  scale_fill_distiller(palette = "Greens", direction = 1) +
  coord_flip() +
  theme(
    axis.title = element_text(
      size = 10,
      face = "bold",
      color = "black"
    ),
    axis.text = element_text(size = 8, color = "black"),
    strip.text = element_text(
      size = 9,
      color = "black",
      face = "bold"
    ),
    panel.background = element_rect(fill = "white"),
    legend.position = "bottom",
    axis.line.x = element_line(color="gray30", linetype = "solid")
  ) +
  labs(y = "Odds Ratio", 
       x = "Pathways", 
       title = "KEGGPathway - POvsBL vs BFpercent (P_Value < 0.01)",
       fill = "-log10(p-value)")  











