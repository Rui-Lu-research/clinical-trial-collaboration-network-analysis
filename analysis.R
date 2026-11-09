#### Clinical Trial Collaboration Network Analysis
#### Rui Lu | UNC Chapel Hill | R, igraph
#### Data: ClinicalTrials.gov snapshot

library(igraph)



trials <- read.csv("clinical_trials_lung_cancer_2020_2024_raw.csv",
                   stringsAsFactors = FALSE, check.names = FALSE)
nrow(trials)
stopifnot(!anyDuplicated(trials[["NCT Number"]]))
trials$year <- as.integer(substr(trials[["Start Date"]], 1, 4))



#### Build sponsor-collaborator pairs 
old_names <- c("Jiangsu Hengrui Pharmaceutical Co., Ltd.",
               "Innovent Biologics, Inc.")
new_names <- c("Jiangsu HengRui Medicine Co., Ltd.",
               "Innovent Biologics (Suzhou) Co. Ltd.")
trials$Collaborators[is.na(trials$Collaborators)] <- ""
collaborators <- strsplit(trials$Collaborators, "|", fixed = TRUE)
pairs <- data.frame(NCT = character(), from = character(), to = character())

for (i in 1:nrow(trials)) {
  sponsor <- trimws(gsub("\\s+", " ", trials$Sponsor[i]))
  partners <- trimws(gsub("\\s+", " ", collaborators[[i]]))
  for (j in 1:2) {
    sponsor[sponsor == old_names[j]] <- new_names[j]
    partners[partners == old_names[j]] <- new_names[j]
  }
  partners <- setdiff(partners[partners != ""], sponsor)
  if (length(partners) > 0) {
    pairs <- rbind(pairs, data.frame(NCT = trials[["NCT Number"]][i],
                                    from = pmin(sponsor, partners),
                                    to = pmax(sponsor, partners)))
  }
}


#### A pair is counted once per trial; collaborators are not linked to each other.
pairs <- unique(pairs)
pairs$weight <- 1
edges <- aggregate(weight ~ from + to, data = pairs, FUN = sum)
edges <- edges[order(edges$from, edges$to), ]
g <- graph_from_data_frame(edges, directed = FALSE)
vcount(g)
ecount(g)


#### Components and centrality: only organizations with a recorded tie are included in this graph.
comp <- components(g)
comp$no
sort(comp$csize, decreasing = TRUE)[1:5]
giant <- induced_subgraph(g, which(comp$membership == which.max(comp$csize)))
deg <- degree(g)


#### Shared-trial counts are frequencies, not path distances
btw <- betweenness(giant, normalized = TRUE, weights = NA)
centrality <- data.frame(organization = names(btw),
                         degree = as.numeric(degree(giant)),
                         betweenness = as.numeric(btw))
centrality <- centrality[order(-centrality$betweenness), ]
centrality[1:10, ]


##### Remove five key institutions and compare with random removal
n <- vcount(g)
baseline <- max(comp$csize) / n
top_bridges <- names(sort(btw, decreasing = TRUE))[1:5]
top_degree <- names(sort(deg, decreasing = TRUE))[1:5]
g_bridge <- delete_vertices(g, top_bridges)
g_degree <- delete_vertices(g, top_degree)
bridge_share <- max(components(g_bridge)$csize) / n
degree_share <- max(components(g_degree)$csize) / n

set.seed(42)
random_share <- numeric(50)
for (i in 1:50) {
  random_nodes <- sample(V(g)$name, 5)
  g_random <- delete_vertices(g, random_nodes)
  random_share[i] <- max(components(g_random)$csize) / n
}
removal <- data.frame(scenario = c("Baseline", "Top 5 bridges", "Top 5 degree", "5 random, mean"),
                      percentage = 100 * c(baseline, bridge_share, degree_share, mean(random_share)))
removal


#### Trial-site footprints by year: this section compares China and the US, and it does not classify every country.
china_only <- us_only <- both <- rep(FALSE, nrow(trials))
for (i in 1:nrow(trials)) {
  if (!is.na(trials$Locations[i]) && trials$Locations[i] != "") {
    sites <- trimws(strsplit(trials$Locations[i], "|", fixed = TRUE)[[1]])
    sites <- sites[sites != ""]
    countries <- trimws(sub(".*,", "", sites))
    china_only[i] <- length(countries) > 0 && all(countries == "China")
    us_only[i] <- length(countries) > 0 && all(countries == "United States")
    both[i] <- "China" %in% countries && "United States" %in% countries
  }
}


#### All trials in each year remain in the denominator, including missing sites.
geography <- data.frame()
for (y in 2020:2024) {
  selected <- trials$year == y
  geography <- rbind(geography, data.frame(
    year = y, all_trials = sum(selected),
    china_only = sum(china_only[selected]), us_only = sum(us_only[selected]),
    china_and_us = sum(both[selected])))
}
geography$china_percent <- 100 * geography$china_only / geography$all_trials
geography$us_percent <- 100 * geography$us_only / geography$all_trials
geography$both_percent <- 100 * geography$china_and_us / geography$all_trials
geography
sum(both)


#### One-time and recurring partnerships
recurring <- edges$weight > 1
partnerships <- data.frame(
  type = c("One-time", "Recurring"),
  pairs = c(sum(!recurring), sum(recurring)))
partnerships$percentage <- 100 * partnerships$pairs / nrow(edges)
partnerships


#### Different denominator: pair-trial events, rather than distinct pairs.
100 * sum(edges$weight[recurring]) / sum(edges$weight)


#### Save the main tables
dir.create("results", showWarnings = FALSE)
write.csv(centrality, "results/centrality.csv", row.names = FALSE)
write.csv(removal, "results/removal.csv", row.names = FALSE)
write.csv(geography, "results/geography.csv", row.names = FALSE)
write.csv(partnerships, "results/partnerships.csv", row.names = FALSE)

#### Figures
graphics.off()
layout(1)
par(mfrow = c(1, 1), cex = 1, xpd = FALSE)

# High-resolution export. After each figure is drawn on screen, save_hd()
# copies it to a 3000 x 3000 PNG (300 dpi) in results/, using the file names
# the README and RESULTS.md link to. On-screen plotting is unchanged.
save_hd <- function(filename) {
  dev.copy(png, filename = file.path("results", filename),
           width = 3000, height = 3000, res = 300)
  dev.off()
}

# Figure 1. Largest component: colors show different network roles.
# Top 5 by degree = many partners; top 5 by betweenness = key bridges.
node_colors <- rep("lightsteelblue2", vcount(giant))
node_colors[V(giant)$name %in% top_degree] <- "goldenrod2"
node_colors[V(giant)$name %in% top_bridges] <- "tomato3"
node_colors[V(giant)$name %in% intersect(top_degree, top_bridges)] <- "mediumpurple3"

node_sizes <- rep(1.5, vcount(giant))
node_sizes[V(giant)$name %in% union(top_degree, top_bridges)] <- 4

layout(matrix(c(1, 2), ncol = 1), heights = c(9, 1))
par(mar = c(0, 0, 1.8, 0))
set.seed(42)
plot(giant, layout = layout_with_kk(giant, weights = NA),
     vertex.size = node_sizes, vertex.label = NA,
     vertex.color = node_colors, vertex.frame.color = NA,
     edge.color = "grey90", edge.width = 0.5,
     margin = 0, main = "")
title("Largest component: hubs and bridges", cex.main = 0.95)

par(mar = c(0, 0, 0, 0))
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1))
legend("top", inset = 0, ncol = 2,
       legend = c("Top 5 in BOTH rankings (3 institutions)", "Bridging top 5, but not partner top 5 (2)",
                  "Partner top 5, but not bridging top 5 (2)", "Other institutions"),
       col = c("mediumpurple3", "tomato3", "goldenrod2", "lightsteelblue2"),
       pch = 19, pt.cex = 0.65, cex = 0.5, bty = "n",
       x.intersp = 0.6, y.intersp = 0.85)
text(0.5, 0.19, "Five institutions with the most partners: 3 purple + 2 gold",
     cex = 0.45)
text(0.5, 0.03, "Five strongest bridges: 3 purple + 2 red",
     cex = 0.45)
save_hd("network.png")

layout(1)
par(mfrow = c(1, 1), mar = c(5.1, 4.1, 4.1, 2.1), cex = 1, xpd = FALSE)


# Figure 2. The seven highest-betweenness institutions and shared partners.
# A shared partner connects directly to at least two of the seven.
key_orgs <- names(sort(btw, decreasing = TRUE))[1:7]
all_partners <- character()
for (org in key_orgs) {
  all_partners <- c(all_partners, V(g)$name[neighbors(g, org)])
}
partner_counts <- table(all_partners)
shared_partners <- setdiff(names(partner_counts[partner_counts >= 2]), key_orgs)
focus <- induced_subgraph(g, c(key_orgs, shared_partners))
vcount(focus)
ecount(focus)

focus_colors <- ifelse(V(focus)$name %in% key_orgs, "steelblue4", "lightsteelblue2")
# Orange identifies a shared partner connected to three focal institutions.
focus_colors[V(focus)$name %in% shared_partners &
               partner_counts[V(focus)$name] >= 3] <- "darkorange2"
focus_labels <- V(focus)$name
focus_labels[!focus_labels %in% key_orgs] <- NA
focus_labels[focus_labels == "Merck Sharp & Dohme LLC"] <- "Merck (MSD)"
focus_labels[focus_labels == "National Cancer Institute (NCI)"] <- "NCI"
focus_labels[focus_labels == "Peking Union Medical College Hospital"] <- "Peking Union\nMedical College Hospital"
focus_labels[V(focus)$name == "Georgetown University"] <- "Georgetown University"
label_distance <- rep(1.2, vcount(focus))
label_distance[V(focus)$name == "Peking Union Medical College Hospital"] <- 2.4

label_angle <- rep(-pi / 2, vcount(focus))
shanghai <- which(V(focus)$name == "Shanghai Chest Hospital")
label_angle[shanghai] <- 0
label_distance[shanghai] <- 8

layout(1)
par(mfrow = c(1, 1), mar = c(6, 1, 3.5, 1), cex = 1, xpd = FALSE)
set.seed(42)
plot(focus, layout = layout_with_kk(focus, weights = NA),
     vertex.size = ifelse(V(focus)$name %in% key_orgs, 13, 6),
     vertex.color = focus_colors, vertex.frame.color = "white",
     vertex.label = focus_labels, vertex.label.color = "black",
     vertex.label.cex = 0.75, vertex.label.dist = label_distance,
     vertex.label.degree = label_angle,
     edge.color = "grey80", edge.width = 1,
     main = "")
title("Key institutions and shared partners\n(selected network)", cex.main = 0.85)
legend("bottomleft", c("Seven focal institutions", "Shared partner: 2 focal ties",
                       "Shared partner: 3 or more focal ties"),
       col = c("steelblue4", "lightsteelblue2", "darkorange2"),
       pch = 19, pt.cex = c(1.1, 0.8, 0.8), cex = 0.6, bty = "n",
       inset = c(0, -0.10), xpd = NA)
save_hd("key_network.png")

# Figure 3. Partner breadth and bridging importance
layout(1)
par(mfrow = c(1, 1), mar = c(5.1, 4.5, 4.1, 2.1), cex = 1, xpd = FALSE)
plot(centrality$degree, centrality$betweenness, pch = 19, col = "steelblue",
     xlab = "Distinct partners (degree)", ylab = "Unweighted betweenness",
     main = "Partner breadth and bridging importance", cex.main = 0.9)
save_hd("centrality.png")

# Figure 4. Structural dependence under node removal
layout(1)
par(mfrow = c(1, 1), mar = c(5.1, 4.5, 4.1, 2.1), cex = 1, xpd = FALSE)
barplot(removal$percentage, names.arg = c("Baseline", "Top 5\nbridges", "Top 5\ndegree", "5 random\nmean"),
        col = c("lightsteelblue", "indianred3", "tan3", "darkseagreen4"),
        ylim = c(0, 85), ylab = "% of original network nodes",
        main = "Structural dependence under node removal", cex.main = 0.9)
save_hd("removal.png")

# Figure 5. Trial-site footprints
layout(1)
par(mfrow = c(1, 1), mar = c(5.1, 4.5, 4.1, 2.1), cex = 1, xpd = FALSE)
matplot(geography$year, geography[, c("china_percent", "us_percent", "both_percent")],
        type = "b", pch = c(16, 17, 15), lty = 1,
        col = c("indianred3", "steelblue", "darkseagreen4"), ylim = c(0, 45),
        xlab = "Study start year", ylab = "% of all trials starting in each year",
        main = "Domestic footprints and direct\nChina-US site integration", cex.main = 0.9)
legend("topleft", c("China only", "US only", "China and US"),
       col = c("indianred3", "steelblue", "darkseagreen4"),
       pch = c(16, 17, 15), lty = 1, bty = "n")
save_hd("geography.png")

# Figure 6. One-time and recurring partnerships
layout(1)
par(mfrow = c(1, 1), mar = c(5.1, 4.5, 4.1, 2.1), cex = 1, xpd = FALSE)
barplot(partnerships$pairs, names.arg = partnerships$type, col = "steelblue",
        ylab = "Distinct institutional pairs", main = "One-time and recurring partnerships", cex.main = 0.9)
save_hd("partnerships.png")


