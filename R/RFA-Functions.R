##function to load xrf-measurements from a folder
# load_xrf function loads CSV files from a specified folder path and combines them into one data frame.

load_xrf <- function(folder_path) {
  # Get a list of file names for all CSV files in the folder
  csv_files <- list.files(path = folder_path, pattern = ".csv", full.names = TRUE)

  # Create an empty list to store the loaded data
  data <- list()

  # Loop through each CSV file and load its data into the list
  for (file in csv_files) {
    # Load data and add it to the list with the file name as the key
    data[[file]] <- read.csv2(file)

  }

  # Function to get the number of columns in a DataFrame
  get_num_columns <- function(df) {
    ncol(df)
  }

  # Get the number of columns in each DataFrame in the list
  num_columns_list <- lapply(data, get_num_columns)

  # Display the number of columns for each DataFrame
  for (i in 1:length(num_columns_list)) {
    cat(paste("DataFrame", csv_files[i], "has", num_columns_list[[i]], "columns.\n"))
  }


  # Combine all loaded data frames into one
  Measurements <- data.frame()
  for (file in csv_files) {
    Measurements <- rbind(Measurements, data[[file]])
  }

  # Loop through each column and replace commas with periods
  for (col in colnames(Measurements)) {
    Measurements <- Measurements |>
      mutate(!!col := str_replace_all(!!sym(col), ",", "."))
  }

  # Replace "<LOD" with 0 and convert columns 1 and 14:107 to numeric
 # Measurements <- Measurements |>
   # mutate(across(everything(), ~ifelse(. == "<LOD", 0, .))) |>
  #  mutate_at(vars(1, 14:107), as.numeric)

  # Removing duplicates
  Measurements <- Measurements |>
    distinct(across(everything()))

  # Return the combined and cleaned data frame
  return(Measurements)
}


##function to get deviations
# deviation_elements function calculates the standard deviation and deviation percentage
# for elements in a dataset based on specified object and category columns.
# It also filters the data based on a threshold value if provided.

deviation_elements <- function(data, object, category, threshold = FALSE) {

  # Pivot the data to long format to work with elements as rows
  data <- data %>%
    pivot_longer(cols = Mo:Mg, names_to = "element", values_to = "value") %>%

    # Group the data by the specified category and filter out groups with only one row
    group_by({{category}}) |>
    filter(n() > 1) |>

    # Group the data by object, category, and element, then calculate standard deviation
    group_by({{object}}, {{category}}, element) |>
    summarise(
      deviation_percent = sd(value) / mean(value) * 100
    )

  # If a threshold is specified, filter the data based on the threshold
  if (threshold != FALSE) {
    data <- data |>
      filter(deviation_percent > threshold | deviation_percent < -threshold)
  }

  return(data)
}

## function to get mean without outlier
# removes outliers based on a threshold using either iqr or z-score
# and then calculates the mean based on the values that are left

remove_outliers_and_calculate_mean <- function(values, threshold = 1.5, method = "iqr") {
  # Check if the method is valid
  if(!method %in% c("z", "iqr")) {
    stop("Invalid method. Use 'z' for Z-score or 'iqr' for Interquartile Range.")
  }

  # Z-score method
  if(method == "z") {
    # Calculate the mean and standard deviation
    mean_value <- mean(values)
    sd_value <- sd(values)

    # Calculate the Z-scores
    z_scores <- (values - mean_value) / sd_value

    # Find values that are within the specified threshold
    non_outliers <- values[abs(z_scores) <= threshold]

  } else if(method == "iqr") {  # IQR method
    # Calculate the IQR (Interquartile Range)
    Q1 <- quantile(values, 0.25)
    Q3 <- quantile(values, 0.75)
    IQR_value <- Q3 - Q1

    # Define the lower and upper bounds for outliers
    lower_bound <- Q1 - threshold * IQR_value
    upper_bound <- Q3 + threshold * IQR_value

    # Find values that are within the IQR-based bounds
    non_outliers <- values[values >= lower_bound & values <= upper_bound]
  }

  # Calculate the mean of the non-outliers
  mean_value <- mean(non_outliers, na.rm = TRUE)

  return(mean_value)
}

remove_outliers_and_calculate_mean <- function(values, threshold = 1.5, method = "iqr") {
  # Remove NA values from the input
  values <- na.omit(values)

  # Check if the method is valid
  if(!method %in% c("z", "iqr")) {
    stop("Invalid method. Use 'z' for Z-score or 'iqr' for Interquartile Range.")
  }

  # Z-score method
  if(method == "z") {
    # Calculate the mean and standard deviation, ignoring NA values
    mean_value <- mean(values, na.rm = TRUE)
    sd_value <- sd(values, na.rm = TRUE)

    # Calculate the Z-scores
    z_scores <- (values - mean_value) / sd_value

    # Find values that are within the specified threshold
    non_outliers <- values[abs(z_scores) <= threshold]

  } else if(method == "iqr") {  # IQR method
    # Calculate the IQR (Interquartile Range), ignoring NA values
    Q1 <- quantile(values, 0.25, na.rm = TRUE)
    Q3 <- quantile(values, 0.75, na.rm = TRUE)
    IQR_value <- Q3 - Q1

    # Define the lower and upper bounds for outliers
    lower_bound <- Q1 - threshold * IQR_value
    upper_bound <- Q3 + threshold * IQR_value

    # Find values that are within the IQR-based bounds
    non_outliers <- values[values >= lower_bound & values <= upper_bound]
  }

  # Calculate the mean of the non-outliers, ignoring NA values
  mean_value <- mean(non_outliers, na.rm = TRUE)

  return(mean_value)
}

# compare_dataframes
## general function to compare to dataframes and get the values that do not match
## enter two dataframes and get every object name and the variable where the two dfs are different

compare_dataframes <- function(df1, df2) {
  # Überprüfen, ob beide DataFrames die gleiche Struktur haben
  if(!all(names(df1) == names(df2))) {
    stop("Die DataFrames haben unterschiedliche Spaltennamen.")
  }

  # Überprüfen, ob beide DataFrames die gleiche Anzahl an Zeilen haben
  if(nrow(df1) != nrow(df2)) {
    stop("Die DataFrames haben unterschiedliche Zeilenanzahl.")
  }

  # Filtern von numerischen Variablen (Spalten)
  numeric_columns <- sapply(df1, is.numeric)

  # Ergebnisse speichern
  differences <- list()

  for(col in names(df1)[numeric_columns]) {
    # Vergleichen der Werte
    unequal_indices <- which(df1[[col]] != df2[[col]])

    if(length(unequal_indices) > 0) {
      # Speichere die Zeilennamen (aus der Spalte "Object") für unterschiedliche Werte
      differences[[col]] <- df1$Object[unequal_indices]
    }
  }

  # Ergebnis anzeigen
  if(length(differences) == 0) {
    message("Alle numerischen Variablen haben identische Werte in beiden DataFrames.")
  } else {
    return(differences)
  }
}


# calculate_mean_sd_percent
## function calculates

calculate_mean_sd_percent <- function(x) {
  mean_value <- mean(x)
  sd_value <- sd(x)
  mean_percent <- (sd_value/ mean_value) * 100  # Durchschnitt in Prozent
  return(mean_percent)
}


#3d plots
## function that creates 3D plots of PCA and allows to get the id of specific objects
plot_3d_pca <- function(data, pca_res, color_by = "Region", shape_by = "Local",
                        custom_colors = NULL, show_arrows = TRUE) {

  # Load necessary libraries
  library(plotly)
  library(FactoMineR)
  library(factoextra)
  library(dplyr)

  # Check if PCA results were provided, if not, perform PCA
  if (missing(pca_res)) {
    pca_res <- PCA(data, graph = FALSE)
  }

  # Extract eigenvalues (percentage of variance explained)
  eig_values <- get_eigenvalue(pca_res)

  # Convert PCA coordinates to a dataframe and add color group information
  pca_data <- as.data.frame(pca_res$ind$coord)
  pca_data[[color_by]] <- data[[color_by]]
  pca_data$Label <- rownames(data)  # Extract labels from row names

  # Define point shapes if 'shape_by' is not FALSE, otherwise, set all points to circles
  if (is.logical(shape_by) && shape_by == FALSE) {
    shape_column <- rep("circle", nrow(pca_data))
  } else {
    pca_data[[shape_by]] <- as.factor(data[[shape_by]])  # Ensure 'shape_by' is a factor
    shape_column <- pca_data[[shape_by]]
  }

  # Extract loadings (arrows showing variable contributions to PCA)
  loadings <- as.data.frame(pca_res$var$coord[, 1:3])
  loadings$length <- sqrt(rowSums(loadings^2))  # Calculate length of each vector for scaling

  # Set default color palette if 'custom_colors' is not provided
  if (is.null(custom_colors)) {
    custom_colors <- c("#FFA500", "brown", "#00008B", "#00FFFF", "#6495ED",
                       "#4682B4", "#ADD8E6", "#1E90FF", "#D2B48C")
  }

  # Define up to 10 different symbols for the shape of the points
  shape_symbols <- c("circle", "square", "diamond", "cross", "x", "triangle-up",
                     "triangle-down", "triangle-left", "triangle-right", "pentagon")

  # If there are more than 10 groups, repeat the symbols
  if (!is.logical(shape_by) || shape_by != FALSE) {
    unique_shapes <- length(unique(pca_data[[shape_by]]))
    if (unique_shapes > length(shape_symbols)) {
      shape_symbols <- rep(shape_symbols, length.out = unique_shapes)
    }
    shape_mapping <- setNames(shape_symbols[1:unique_shapes], unique(pca_data[[shape_by]]))
  } else {
    shape_mapping <- setNames(rep("circle", length(shape_column)), shape_column)
  }

  # Create 3D scatter plot with PCA individuals
  fig <- plot_ly(data = pca_data) %>%
    add_markers(x = ~Dim.1,
                y = ~Dim.2,
                z = ~Dim.3,
                color = ~get(color_by),  # Color by the specified column
                symbol = shape_column,   # Shape based on the specified column
                colors = custom_colors,  # Apply the custom color palette
                symbols = shape_mapping,
                text = ~Label,           # Display individual name on hover
                hoverinfo = 'text') %>%
    layout(scene = list(xaxis = list(title = paste('Dim.1 (', round(eig_values[1, 2], 2), '%)', sep = '')),
                        yaxis = list(title = paste('Dim.2 (', round(eig_values[2, 2], 2), '%)', sep = '')),
                        zaxis = list(title = paste('Dim.3 (', round(eig_values[3, 2], 2), '%)', sep = ''))),
           title = "3D PCA Plot")

  # Add loading arrows (vectors) to the plot if 'show_arrows' is TRUE
  if (show_arrows) {
    colors <- colorRampPalette(c("blue", "red"))(nrow(loadings)) # Create a color gradient
    for (i in 1:nrow(loadings)) {
      fig <- fig %>%
        add_trace(type = 'scatter3d', mode = 'lines',
                  x = c(0, loadings[i, 1]),
                  y = c(0, loadings[i, 2]),
                  z = c(0, loadings[i, 3]),
                  line = list(width = loadings$length[i] * 5, color = colors[i]), # Adjust width and color
                  name = rownames(loadings)[i],  # Add name to the legend
                  showlegend = TRUE) %>%
        add_text(x = loadings[i, 1],
                 y = loadings[i, 2],
                 z = loadings[i, 3],
                 text = rownames(loadings)[i],
                 textposition = 'top middle',
                 showlegend = FALSE)
    }
  }

  # Display the 3D plot
  return(fig)
}
