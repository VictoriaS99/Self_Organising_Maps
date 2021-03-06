#set work dir
setwd("M:/Visual Analytics/SOM")

#import all required libraries
library(kohonen)
library(Rcpp)
library(ggplot2)
library(sf)
library(rgdal)
library(gridExtra)
library(grid)
library(viridis)
library(dplyr)
library(caret) #streamlined library for data preparation for machine learning 
models
library(RColorBrewer)
library(cluster) #used for k-means estimation model training
library(factoextra) #complements 'cluster' lib to visualise k-means statistic

#read in csv
data <-
  read.csv(file = "Assessment Data\\SIMD16 indicator data.csv", sep = ',', header = TRUE) 

#filter to only Edi
data <- data[1912:2508, ]

#read in SIMD 2016 shp
#do not re-encode strings to factors (distinct groups) during loading
edi_simd <-
  readOGR("Assessment Data\\SG_SIMD_2016_EDINBURGH.shp",
          stringsAsFactors = FALSE)

#DATA PROCESSING -----
#project spatial polygon to WGS84
edi_map_sdf <-
  spTransform(edi_simd,
              CRS("+proj=longlat +ellps=WGS84
 +datum=WGS84 +no_defs"))

#convert spatial df to normal df
edi_map_df <- as.data.frame(edi_map_sdf)

#fortify spatial df to attach lat and long
#this is to allow for plotting
edi_fort <- fortify(edi_map_sdf, region = "DataZone")

#as fortify loses the relational join between the df and its fortified ver
#need to merge the two back together
edi_fort <-
  merge(edi_fort, edi_map_df, by.x = "id", by.y = "DataZone")

##Income ------
#select relevant col and transform to numeric value
income <- edi_map_df[, 10]

##Employment ----
#repeat for employment 
employment <- edi_map_df[, 13]

##Health -----
#extract all relevant cols
health <- subset(edi_map_df, select = c(16, 17, 18, 19, 20, 21, 22))
#using preProcess class from 'caret' library to scale/normalise data from 0-1
health_norm <- preProcess(health, method = c("range"))
health_norm <- predict(health_norm, health[, c(1, 2, 3, 4, 5, 6, 7)])
#check to see whether normalisation was a success; max values should all be 1
summary(health_norm)
#sum all rows in normalised vector to form overall health domain variable
health_all <- rowSums(health_norm[, c(1, 2, 3, 4, 5, 6, 7)])

##Education ----
#repeat all steps above for education domain
edu <- subset(edi_map_df, select = c(24, 25, 26, 27, 28))
#normalise
edu_norm <- preProcess(edu, method = c("range"))
edu_norm <- predict(edu_norm, edu[, c(1, 2, 3, 4, 5)])
summary(edu_norm)
edu_all <- rowSums(edu_norm[, c(1, 2, 3, 4, 5)])

##Access ----
#repeat steps for access domain
access <- subset(edi_map_df, select = c(30, 31, 32, 33, 34, 35, 36, 37, 38))
access_norm <- preProcess(access, method = c("range"))
access_norm <- predict(access_norm, access[, c(1, 2, 3, 4, 5, 6, 7, 8, 9)])
summary(access_norm)
access_all <- rowSums(access_norm[, c(1, 2, 3, 4, 5, 6, 7, 8, 9)]
                      
                      ##Crime ----
                      crime <- subset(edi_map_df, select = c(41))
                      #need for converting factor to numeric here otherwise won't scale correctly
                      crime <- as.numeric(as.character(unlist(crime)))
                      ##Housing -----
                      #repeat again for housing domain
                      housing <- subset(edi_map_df, select = c(45, 46))
                      housing_norm <- preProcess(housing, method = c("range"))
                      housing_norm <- predict(housing_norm, housing[, c(1, 2)])
                      summary(housing_norm)
                      housing_all <- rowSums(housing_norm[, c(1, 2)])
                      
                      
                      #Creation of Domain Matrix taking in all normalised individual domains above ----
                      #sum all domains into a matrix for greater efficiency when running code
                      #nrow set to the length of any domain var to ensure each column captures one domain only
                      domains_all <-
                        as.data.frame(matrix(
                          c(
                            income,
                            employment,
                            health_all,
                            access_all,
                            edu_all,
                            crime,
                            housing_all
                          ),
                          nrow = length(access_all)
                        ))
                      
                      #rename to SIMD domain names
                      names(domains_all) <-
                        c("Income",
                          "Employment",
                          "Health",
                          "Access",
                          "Education",
                          "Crime",
                          "Housing")
                      
                      #standardise all values in combined domains matrix
                      domains_scaled <- as.matrix(scale(domains_all))
                      
                      #phew...I made it through the data processing stage, so now let's roll onto 
                      model training!
                        
                        
                        #SOM Model Set-Up ----
                      #first set.seed to ensure repeatability in future runs
                      #value can be random, i.e. has no meaning to the actual training
                      set.seed(56)
                      
                      #define SOM grid size and topology
                      #"One-Half" rule of grid size
                      som_grid <-
                        somgrid(
                          xdim = 13,
                          ydim = 10,
                          topo = "hexagonal",
                          neighbourhood.fct = "gaussian"
                        )
                      
                      #train model
                      #matrix presented to network 300 times initially but did not stabilise enough
                      som_model <- som(
                        domains_scaled,
                        grid = som_grid,
                        rlen = 800,
                        alpha = c(0.01, 0.01),
                        keep.data = TRUE
                      )
                      
                      #plot training curve
                      plot(som_model, type = "changes")
                      #set plotting layout dimensions
                      par(mfrow = c(1, 2))
                      
                      #map quality 1 (counts) -----
                      plot(
                        som_model,
                        type = "count",
                        main = "Node Counts",
                        shape = "straight",
                        border = "transparent",
                        heatkey = TRUE,
                        heatkeywidth = 0.4
                      )
                      
                      #map quality 2 (distance) ----
                      plot(
                        som_model,
                        type = "quality",
                        main = "Node Quality/Distance",
                        shape = "straight",
                        heatkey = TRUE,
                        heatkeywidth = 0.4
                      )
                      
                      #U-matrix ----
                      #the lower the distance value the more similar the nodes
                      plot(
                        som_model,
                        type = "dist.neighbours",
                        main = "SOM neighbour distances",
                        shape = "straight",
                        palette.name = grey.colors,
                        border = "black"
                      )
                      
                      #clustering of som -----
                      #extract codebook (reference) vectors from som
                      mydata <- getCodes(som_model)
                      wcss <- (nrow(mydata) - 1) * sum(apply(mydata, 2, var))
                      for (i in 2:13) {
                        wcss[i] <- sum(kmeans(mydata,
                                              centers = i)$withinss)
                      } #2:15 is selected to allow exploration of what the optimal number of clusters are in WCSS plot
                      
                      #plot wcss
                      plot(
                        wcss,
                        type = "b",
                        xlab = "Number of Clusters",
                        ylab = "Within groups sum of squares",
                        main = "Within cluster sum of squares (WCSS)"
                      )
                      
                      # as the WCSS curve leaves us apprehensive,let's explore further...
                      # compute gap statistic
                      set.seed(123) 
                      gap_stat <- clusGap(mydata, FUN = kmeans, nstart = 20,
                                          K.max = 15, B = 50) #nstart = initial configurations befo
                      re data is trained; K.max = max. no. of clusters to train; B = number of (monte carlo) simulations
                      
                      # Print the result
                      print(gap_stat, method = "firstmax") #observe gap statistic
                      
                      #visualise result
                      fviz_gap_stat(gap_stat) + theme_minimal() + ggtitle("Gap Statistic")
                      
                      #first define colours of the clusters
                      cbPalette <-
                        c("#CC79A7",
                          "#56B4E9",
                          "#009E73",
                          "#F0E442",
                          "#0072B2",
                          "#D55E00",
                          "#CC3545")
                      
                      #visualise clusters on grid ------
                      #split into 7 categories
                      som_cluster <- cutree(hclust(dist(getCodes(som_model))), 7)
                      
                      #plot clusters only -----
                      set.seed(54) #again to ensure repeatability
                      plot(som_model,
                           type = "mapping",
                           bg = cbPalette[som_cluster],
                           main = "Clusters with Circles")
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      #plot clusters with segment codebook vector
                      plot(
                        som_model,
                        type = "codes",
                        bg = cbPalette[som_cluster],
                        main =
                          "Clusters with Codebook Vectors",
                        shape = "straight",
                        border = "grey"
                      )
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      #let's see what kind of areas overlie these clusters to get a sense of the 
                      locations
                      #first get names from shp
                      dz_names <- edi_simd@data$Intermedia
                      
                      # find all duplicate values and set them to NA
                      dz_names[duplicated(dz_names)] <- NA
                      
                      #find the index of the names which are not NA
                      naset <- which(!is.na(dz_names))
                      
                      #take RANDOM sample of placenames with length less than 10 and set them as NA
                      naset <- sample(naset, length(naset) - 10)
                      dz_names[naset] <- NA
                      
                      #view the names which have been selected
                      #View(which(!is.na(dz_names)))
                      
                      # Replot our data with labels=dz_names
                      plot(
                        som_model,
                        type = "mapping",
                        bg = cbPalette[som_cluster],
                        main =
                          "Clusters with Datazone Names",
                        shape = "straight",
                        border = "grey"
                        labels = dz_names
                      )
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      ## Create unscaled correlation maps -----
                      var <- 1 #define the variable to plot 
                      
                      par(mai=rep(0.5, 4)) #plotting for 3 graphs – one centred at bottom
                      
                      layout(matrix(c(1,1, 2,2, 0, 3,3, 0), ncol = 4, byrow = TRUE))
                      plot(som_model, type = "property", property = getCodes(som_model)[,var], shap
                           e = "straight",
                           border = "grey", main=colnames(getCodes(som_model))[1], bg = cbPalette)
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      plot(som_model, type = "property", property = getCodes(som_model)[,2], shape 
                           = "straight",
                           border = "grey", main=colnames(getCodes(som_model))[2], bg = cbPalette)
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      plot(som_model, type = "property", property = getCodes(som_model)[,3], shape 
                           = "straight",
                           border = "grey", main=colnames(getCodes(som_model))[3], bg = cbPalette)
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      dev.off() #turn off manually-defined plotting dimensions
                      
                      par(mfrow=c(2,2)) #2 rows, 2 cols
                      
                      plot(som_model, type = "property", property = getCodes(som_model)[,4], shape 
                           = "straight",
                           border = "grey", main=colnames(getCodes(som_model))[4], bg = cbPalette)
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      plot(som_model, type = "property", property = getCodes(som_model)[,5], shape 
                           = "straight",
                           border = "grey", main=colnames(getCodes(som_model))[5], bg = cbPalette)
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      plot(som_model, type = "property", property = getCodes(som_model)[,6], shape 
                           = "straight",
                           border = "grey", main=colnames(getCodes(som_model))[6], bg = cbPalette)
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      plot(som_model, type = "property", property = getCodes(som_model)[,7], shape 
                           = "straight",
                           border = "grey", main=colnames(getCodes(som_model))[7], bg = cbPalette)
                      add.cluster.boundaries(som_model, som_cluster)
                      
                      #plotting som to shp file -------
                      #create df of the dz id (from shp) and the cluster unit (vector counts to BMU
) in each area
cluster_details <-
  data.frame(id = data$Data_Zone, cluster = som_cluster[som_model$unit.classif])

#View(cluster_details)

#merge our cluster details with the fortified spatial polygon dataframe from 
earlier
mappoints <- merge(edi_fort, cluster_details, by = "id")

# map clusters onto shp and colour by cluster using ggplot
ggplot(data = mappoints,
       aes(
         x = long,
         y = lat,
         group = group,
         fill = factor(cluster)
       )) +
  geom_polygon(colour="lightgrey", size = 0.001) + #note: no need to define s
  patial polygon here as we have fortified and joined with shp
theme_void(
  base_size = 15,
  #controls size of the plot
  base_family = "",
  base_line_size = base_size / 22,
  base_rect_size = base_size / 22
) + coord_equal() +
  scale_fill_manual(name = "SOM Clusters", values = cbPalette)

#combine the simd onto our original spatial polygon
edi_map_clusters <-
  merge(edi_simd, data, by.x = "DataZone", by.y = "Data_Zone")
#merge cluster data to original spatial polygon
edi_map_clusters <-
  merge(edi_map_clusters,
        cluster_details,
        by.x = "DataZone",
        by.y = "id")

View(edi_map_clusters)

#export edi_map_clusters as an esri shapefile using OGR -----
#dsn = folder name
#layer = name of shp to be exported
#overwrite is true
writeOGR(
  obj = edi_map_clusters,
  dsn = "SOM_outcome_map",
  layer = "edi_map_clusters",
  driver = "ESRI Shapefile",
  check_exists = TRUE,
  overwrite_layer = TRUE
)


#Statistical testing -----
#load up shp with ranks; previous one loaded did not have that in
simd_2016_ranks <-
  readOGR("Assessment Data/SG_SIMD_2016.shp", stringsAsFactors = FALSE)

#since the shp exists for the whole of Scotland, subset to include
#rows containing Edinburgh only
edi_simd_ranks <-
  simd_2016_ranks[grepl("Edinburgh", simd_2016_ranks[["LAName"]]), ]

#convert spatial df to normal df
edi_simd_ranks <- as.data.frame(edi_simd_ranks)

#join 2 dfs together to get simd scores and clusters 
simd_clusters <-
  merge(cluster_details,
        edi_simd_ranks,
        by.x = "id",
        by.y = "DataZone")

#create new df with filtered cols
simd_clusters_clean <- subset(simd_clusters, select = c(2, 6))

#convert cluster to factors data type
simd_clusters_clean$cluster <-
  as.factor(as.character(simd_clusters_clean$cluster))

# Creating a boxplot with ggplot
(
  simd_boxplot <-
    ggplot(simd_clusters_clean, aes(
      x = cluster, y = Rank,
      fill = cluster
    )) +
    geom_boxplot() +
    labs(x = "\nCluster number", y = "SIMD rank (per datazone)", title = "Box
plot showing distribution of SIMD rank per cluster group")
) +
  scale_fill_manual(values = c(
    "#CC79A7",
    "#56B4E9",
    "#009E73",
    "#F0E442",
    "#0072B2",
    "#D55E00",
    "#CC3545"
  )) +
  theme_minimal()

#running one-way ANOVA -----
# dependent var ~ independent var
simd_anova <- aov(Rank ~ cluster, data = simd_clusters_clean)
summary(simd_anova)

# Checking normality
par(mfrow = c(1, 2)) # This code put two plots in the same window
hist(simd_anova$residuals) # Makes histogram of residuals
plot(simd_anova, which = 2) # Makes Q-Q plot
# Checking homoscedasticity (Homogeneity of variances)
plot(simd_anova, which = 1) # Makes residuals VS fitted plot

#summary stats of clusters
summary_stats <- simd_clusters_clean %>%
  group_by(cluster) %>%
  summarise(
    n = n(),
    # Calculating sample size n
    average_SIMD_rank = mean(Rank),
    SD = sd(Rank)
  ) %>% # Calculating standard deviation
  mutate(SE = SD / sqrt(n)) # Calculating standard error

print(summary_stats)