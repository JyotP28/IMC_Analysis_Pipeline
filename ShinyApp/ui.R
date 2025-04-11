# ui.R
library(shiny)
library(shinyFiles)
library(shinyjs)
library(DT)
library(shinydashboard)

dashboardPage(
  dashboardHeader(title = "Spectre Shiny App"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Data Input", tabName = "data_input", icon = icon("upload")),
      menuItem("Transformation", tabName = "transformation", icon = icon("sliders-h")),
      menuItem("Feature Selection", tabName = "feature_selection", icon = icon("check-square")),
      menuItem("Subsampling", tabName = "subsampling", icon = icon("sample")),
      menuItem("Analysis", tabName = "analysis", icon = icon("cog")),
      menuItem("Cluster Annotation", tabName = "annotation", icon = icon("tags")),
      menuItem("Visualization", tabName = "visualization", icon = icon("chart-scatter")),
      menuItem("Data Exploration", tabName = "exploration", icon = icon("table"))
    )
  ),
  dashboardBody(
    useShinyjs(),
    tabItems(
      tabItem(tabName = "data_input",
              h4("Data Input"),
              shinyDirButton('dataDir', 'Select Data Directory', 'Please select a directory containing your CSV or FCS files'),
              verbatimTextOutput('dataDirPath'),
              fileInput("metaFile", "Choose Metadata File (CSV)", accept = ".csv"),
              textInput("sample_col_name", "Sample Column Name in Metadata", value = "Sample"),
              textInput("group_col_name", "Group Column Name in Metadata", value = "Group")
      ),
      tabItem(tabName = "transformation",
              h4("Transformation"),
              uiOutput("asinh_cols_range_ui"),
              numericInput("asinh_cofactor", "Arcsinh Cofactor", value = 5)
      ),
      tabItem(tabName = "feature_selection",
              h4("Marker & Clustering Columns"),
              uiOutput("marker_cluster_cols_range_ui")
      ),
      tabItem(tabName = "subsampling",
              h4("Subsampling"),
              uiOutput("subsampling_options_ui")
      ),
      tabItem(tabName = "analysis",
              h4("Analysis"),
              numericInput("n_clusters", "Number of Clusters (k)", value = 10),
              actionButton("run_analysis", "Run Analysis")
      ),
      tabItem(tabName = "annotation",
              h4("Apply Annotations via R Code"),
              p("Enter R code below to define your cluster annotations. The code should create a data frame named 'annotation_table' with columns 'Cluster' (numeric) and 'Population' (character)."),
              textAreaInput("annotation_code", "R Code for Annotations:", rows = 5,
                            placeholder = 'Example:\nannotation_table <- data.frame(Cluster = c(1, 2, 3), Population = c("NK cells", "CD8 T cells", "CD4 T cells"))'),
              actionButton("apply_code_annotations", "Apply Annotations"),
              verbatimTextOutput("annotation_code_error") # To display any errors in user code
      ),
      tabItem(tabName = "visualization",
              h4("User Defined Plotting"),
              uiOutput("user_plot_ui"),
              plotOutput("rendered_user_plot")
      ),
      tabItem(tabName = "exploration",
              h4("Data Exploration"),
              checkboxInput("show_summary", "Show Data Summary", FALSE),
              checkboxInput("show_transformed", "Show Transformed Data Preview", FALSE),
              conditionalPanel(
                condition = "input.show_summary",
                h4("Merged Data Summary"),
                verbatimTextOutput("data_summary")
              ),
              conditionalPanel(
                condition = "input.show_transformed",
                h4("Transformed Data Preview"),
                DTOutput("transformed_preview")
              ),
              downloadButton("downloadAnnotatedData", "Download Annotated Data (CSV)")
      )
    )
  )
)