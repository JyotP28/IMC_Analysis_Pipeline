# server.R
library(shiny)
library(shinyFiles)
library(data.table)
library(Spectre)
library(ggplot2)
library(pheatmap)
library(magrittr)
library(shinyjs)
library(DT)
library(RColorBrewer)

shinyServer(function(input, output, session) {
  
  # --- Include shinyjs ---
  useShinyjs()
  
  # --- Directory Selection ---
  volumes <- c(Home = Sys.getenv("HOME"))
  shinyDirChoose(input, 'dataDir', roots = volumes, filetypes = c('', ''))
  output$dataDirPath <- renderPrint({ parseDirPath(volumes, input$dataDir) })
  
  # --- Data Input and Merging ---
  data.list <- reactive({
    data_dir <- parseDirPath(volumes, input$dataDir)
    if (length(data_dir) > 0) {
      file_paths <- list.files(data_dir, pattern = "\\.(csv|fcs)$", full.names = TRUE)
      data_frames <- lapply(seq_along(file_paths), function(i) {
        df <- fread(file_paths[i], data.table = FALSE)
        filename <- gsub("\\.(csv|fcs)$", "", basename(file_paths[i]))
        df$FileName <- filename
        df
      })
      data_frames
    } else {
      NULL
    }
  })
  
  cell.dat <- reactive({
    if (!is.null(data.list())) {
      Spectre::do.merge.files(dat = data.list())
    } else {
      NULL
    }
  })
  
  # --- Metadata Import and Joining ---
  meta.dat <- reactive({
    req(input$metaFile)
    fread(input$metaFile$datapath)
  })
  
  cell.dat.with.meta <- reactive({
    req(cell.dat(), meta.dat(), input$sample_col_name, input$group_col_name)
    
    sample.info <- meta.dat()[, c("Filename", input$sample_col_name, input$group_col_name), with = FALSE]
    setnames(sample.info, input$sample_col_name, "Sample")
    
    merged_data <- Spectre::do.add.cols(cell.dat(), "FileName", sample.info, "Filename", rmv.ext = TRUE)
    
    # Filter out rows where the group column is NA
    merged_data <- merged_data[!is.na(merged_data[[input$group_col_name]])]
    
    merged_data
  })
  
  # --- Dynamic UI for Arcsinh Column Selection (Range) ---
  output$asinh_cols_range_ui <- renderUI({
    req(cell.dat.with.meta())
    column_names <- names(cell.dat.with.meta())
    tagList(
      selectInput("asinh_start_col", "Select First Column for Arcsinh", choices = column_names),
      selectInput("asinh_end_col", "Select Last Column for Arcsinh", choices = column_names),
      actionButton("select_asinh_range", "Select Range")
    )
  })
  
  to.asinh <- reactiveVal()
  
  observeEvent(input$select_asinh_range, {
    req(input$asinh_start_col, input$asinh_end_col, cell.dat.with.meta())
    column_names <- names(cell.dat.with.meta())
    start_index <- which(column_names == input$asinh_start_col)
    end_index <- which(column_names == input$asinh_end_col)
    
    if (length(start_index) > 0 && length(end_index) > 0 && start_index <= end_index) {
      selected_range <- column_names[start_index:end_index]
      to.asinh(selected_range)
    } else {
      showNotification("Invalid column range selected for Arcsinh.", type = "warning")
      to.asinh(character(0))
    }
  })
  
  # --- Data Transformation ---
  cell.dat.transformed <- reactive({
    req(cell.dat.with.meta(), to.asinh(), input$asinh_cofactor)
    if (length(to.asinh()) > 0) {
      Spectre::do.asinh(cell.dat.with.meta(), to.asinh(), cofactor = input$asinh_cofactor)
    } else {
      cell.dat.with.meta()
    }
  })
  
  # --- Dynamic UI for Marker and Clustering Column Selection (Single Range) ---
  output$marker_cluster_cols_range_ui <- renderUI({
    req(cell.dat.transformed())
    column_names <- names(cell.dat.transformed())
    tagList(
      selectInput("marker_cluster_start_col", "Select First Column for Markers & Clustering", choices = column_names),
      selectInput("marker_cluster_end_col", "Select Last Column for Markers & Clustering", choices = column_names),
      actionButton("select_marker_cluster_range", "Select Range")
    )
  })
  
  cluster.cols <- reactiveVal()
  
  observeEvent(input$select_marker_cluster_range, {
    req(input$marker_cluster_start_col, input$marker_cluster_end_col, cell.dat.transformed())
    column_names <- names(cell.dat.transformed())
    start_index <- which(column_names == input$marker_cluster_start_col)
    end_index <- which(column_names == input$marker_cluster_end_col)
    
    if (length(start_index) > 0 && length(end_index) > 0 && start_index <= end_index) {
      selected_range <- column_names[start_index:end_index]
      cluster.cols(selected_range)
    } else {
      showNotification("Invalid column range selected for Markers & Clustering.", type = "warning")
      cluster.cols(character(0))
    }
  })
  
  # --- Dynamic UI for Subsampling Options ---
  output$subsampling_options_ui <- renderUI({
    req(cell.dat.with.meta(), input$group_col_name)
    
    group.col <- input$group_col_name
    
    if (group.col %in% names(cell.dat.with.meta())) {
      group_counts <- table(cell.dat.with.meta()[[group.col]])
      group_names <- names(group_counts)
      lapply(group_names, function(group) {
        numericInput(
          inputId = paste0("subsample_target_", gsub("[[:space:]]", "_", group)),
          label = paste0("Subsample target for '", group, "' (Total: ", group_counts[group], ")"),
          value = min(2000, group_counts[group], na.rm = TRUE)
        )
      })
    } else {
      p("Please ensure the 'Group Column Name' is correct to see subsampling options.")
    }
  })
  
  # --- Subsample Targets List (Moved outside analysis_results) ---
  sub_targets_list <- reactive({
    data_for_groups <- cell.dat.transformed()
    group.col <- input$group_col_name
    if (group.col %in% names(data_for_groups)) {
      group_levels_data <- as.character(unique(data_for_groups[[group.col]]))
      
      targets <- setNames(numeric(length(group_levels_data)), group_levels_data)
      for (group in group_levels_data) {
        input_id <- paste0("subsample_target_", gsub("[[:space:]]", "_", group))
        if (!is.null(input[[input_id]])) {
          targets[group] <- input[[input_id]]
        } else {
          showNotification(paste("Warning: Subsample target not found for group:", group), type = "warning")
        }
      }
      return(targets)
    } else {
      return(NULL)
    }
  })
  
  # --- Main Analysis ---
  analysis_results <- eventReactive(input$run_analysis, {
    print("Run Analysis button clicked") # Debugging
    req(cell.dat.transformed(), cluster.cols(), input$group_col_name, input$n_clusters, sub_targets_list())
    
    group.col <- input$group_col_name
    
    print("--- Marker/Cluster Columns Selected ---")
    print(cluster.cols())
    
    if (!group.col %in% names(cell.dat.transformed())) {
      showNotification(paste("Error: Group column '", group.col, "' not found in transformed data."), type = "error")
      return(NULL)
    }
    
    withProgress(message = 'Running Analysis...', value = 0, {
      # Subsampling
      cell.sub_data <- Spectre::do.subsample(cell.dat.transformed(),
                                             targets = sub_targets_list(),
                                             divide.by = group.col)
      if (is.null(cell.sub_data)) return(NULL)
      
      # Clustering
      cell.dat_clustered_data <- Spectre::run.flowsom(cell.sub_data, cluster.cols(), meta.k = input$n_clusters)
      if (is.null(cell.dat_clustered_data)) return(NULL)
      
      # Dimensionality Reduction
      cell.sub_umap_data <- Spectre::run.umap(cell.dat_clustered_data, cluster.cols())
      if (is.null(cell.sub_umap_data)) return(NULL)
      
      # Aggregate expression for heatmap
      exp_data <- Spectre::do.aggregate(cell.sub_umap_data, cluster.cols(), by = "FlowSOM_metacluster")
      
      list(
        cell.sub = cell.dat_clustered_data,
        cell.sub.umap = cell.sub_umap_data,
        exp = exp_data
      )
    })
  })
  
  # --- Trigger Analysis on Run Analysis Button Click ---
  observeEvent(input$run_analysis, {
    analysis_results() # Calling it here will trigger the analysis
    showNotification("Analysis complete!", type = "message") # Optional: Notify user
  })
  
  # --- Reactive value to store annotations from user code ---
  user_annotations <- reactiveVal(NULL)
  annotation_code_error <- reactiveVal(NULL)
  
  # --- Observe event for applying user-defined annotation code ---
  observeEvent(input$apply_code_annotations, {
    annotation_code_error(NULL) # Clear any previous errors
    user_code <- input$annotation_code
    if (!is.null(user_code) && user_code != "") {
      tryCatch({
        local_env <- new.env()
        eval(parse(text = user_code), envir = local_env)
        annotation_table <- get("annotation_table", envir = local_env)
        
        # Basic validation of the annotation table
        if (!is.data.frame(annotation_table) || !all(c("Cluster", "Population") %in% names(annotation_table))) {
          annotation_code_error("Error: The code must create a data frame named 'annotation_table' with columns 'Cluster' and 'Population'.")
          user_annotations(NULL)
        } else {
          annotation_table$Cluster <- as.numeric(annotation_table$Cluster)
          user_annotations(annotation_table)
        }
      }, error = function(e) {
        annotation_code_error(paste("Error in user-provided code:", e$message))
        user_annotations(NULL)
      })
    } else {
      annotation_code_error("Please enter R code to define your annotations.")
      user_annotations(NULL)
    }
  })
  
  # --- Output to display errors in annotation code ---
  output$annotation_code_error <- renderText({
    annotation_code_error()
  })
  
  # --- Apply annotations to the UMAP data using user-defined annotations ---
  annotated_data <- reactiveVal(NULL)
  
  observeEvent(input$apply_code_annotations, { # Trigger on the same button
    annotation_code_error(NULL) # Clear any previous errors
    user_code <- input$annotation_code
    if (!is.null(user_code) && user_code != "") {
      tryCatch({
        local_env <- new.env()
        eval(parse(text = user_code), envir = local_env)
        annots_list <- get("annots", envir = local_env)
        
        # Convert the annotation list to a table format
        annots_table <- Spectre::do.list.switch(annots_list)
        names(annots_table) <- c("Values", "Population")
        data.table::setorderv(annots_table, 'Values')
        
        # Explicitly convert 'Values' to character
        annots_table[, Values := as.character(Values)]
        
        # Ensure cell.dat for annotation is a data.table
        cell.dat_for_annotation <- data.table::as.data.table(analysis_results()$cell.sub)
        
        # Add annotations using do.add.cols
        annotated_cell_dat <- Spectre::do.add.cols(cell.dat_for_annotation, "FlowSOM_metacluster", annots_table, "Values")
        
        # Merge the annotated data with UMAP coordinates
        umap_for_merge <- data.table::as.data.table(analysis_results()$cell.sub.umap)[, c("FlowSOM_metacluster", "UMAP_X", "UMAP_Y")]
        final_annotated_data <- merge(annotated_cell_dat, umap_for_merge, by = "FlowSOM_metacluster", all.x = TRUE)
        
        # Update annotated_data
        annotated_data(final_annotated_data)
        
        showNotification("Annotations applied!", type = "message")
        
        # Debugging prints (keep for now)
        print("User-defined annotations (list):")
        print(annots_list)
        print("Converted annotation table:")
        print(annots_table)
        print("Data types before annotation merge:")
        print(paste("Type of FlowSOM_metacluster in cell.dat_for_annotation:", class(cell.dat_for_annotation$FlowSOM_metacluster)))
        print(paste("Type of Values in annots_table:", class(annots_table$Values)))
        print("Column names in final_annotated_data after merge:")
        print(names(final_annotated_data))
        print("First few rows of final_annotated_data:")
        print(head(final_annotated_data))
        
      }, error = function(e) {
        annotation_code_error(paste("Error in user-provided code:", e$message))
        user_annotations(NULL)
      })
    } else {
      annotation_code_error("Please enter R code to define your annotations.")
      user_annotations(NULL)
    }
  })
  # --- User-Defined Plotting ---
  output$user_plot_ui <- renderUI({
    tagList(
      textAreaInput("user_plot_code", "Enter R code for plotting:", rows = 5, placeholder = "Example: make.colour.plot(cell.sub, 'UMAP_X', 'UMAP_Y', 'Population', col.type = 'factor', add.label = TRUE)"),
      actionButton("run_user_plot", "Generate User Plot")
    )
  })
  
  user_plot <- eventReactive(input$run_user_plot, {
    req(input$user_plot_code, annotated_data(), cluster.cols())
    tryCatch({
      local({
        cell.sub <- annotated_data()
        cellular.cols <- cluster.cols()
        
        # Check if 'Population' column exists
        if (!"Population" %in% names(cell.sub)) {
          stop("Error: 'Population' column not found in the annotated data.")
        }
        
        eval(parse(text = input$user_plot_code))
      })
    }, error = function(e) {
      showNotification(paste("Error in user-provided code:", e$message), type = "error", duration = NULL)
      NULL
    })
  })
  
  output$rendered_user_plot <- renderPlot({
    user_plot()
  })
  
  output$data_summary <- renderPrint({
    req(input$show_summary, cell.dat.with.meta())
    summary(cell.dat.with.meta())
  })
  
  output$transformed_preview <- renderDT({
    req(input$show_transformed, cell.dat.transformed())
    head(cell.dat.transformed())
  })
  
  # --- Download Annotated Data ---
  output$downloadAnnotatedData <- downloadHandler(
    filename = function() {
      paste0("annotated_data_", Sys.Date(), ".csv")
    },
    content = function(file) {
      annotated_data_for_download <- annotated_data()
      if (!is.null(annotated_data_for_download)) {
        fwrite(annotated_data_for_download, file)
      } else {
        write.csv("No annotated data available.", file)
      }
    }
  )
  
})