# IMC Analysis Workflow

### Table of Contents

- [Preprocessing .mcd Files](#preprocessing-mcd-files)  
- [Creating a Cell Mask](#creating-a-cell-mask)  
- [Extracting Single Cell Information](#extracting-single-cell-information)  
- [Visualizing Single Cell Data](#visualizing-single-cell-data)






The following is the workflow and analysis pipleine that was used for Jyot Patel's IMM450Y1 project surrounding analysis of IMC acquisitions of NNC and PMS Hippocampi. Additionally, there is a folder containing a work-in-progress ShinyApp to make this analysis more user-friendly.

## Preprocessing .mcd Files
### Prerequisites:

- .mcd files of the acquisitions
- Windows computer with MCD Viewer installed

Before we begin the analysis step, we need to process the .mcd files into a format that the programs that we will use in this workflow can read. For this, we will require a windows computer that has MCD Viewer installed.

### Steps to follow

1. Open your .mcd file in MCD viewer
2. In the panorama setting, select ROI (region of interest), and then in ROI, select the one that you want to analyze (e.g. CA2 hippocampus)
	1. Let it load completely (marked by the purple progress bar in the bottom left.
3. On the top left of the window, click file → export
    1. The export type should be OME-TIFF 16 bit (32 bit requires considerably more processing power)
    2. The page type should be single (this will create individual TIFF files for each marker in the panel
    3. I suggest leaving the file name the same as the .mcd file. Clicking the three dots next to this will allow you to select a location to save the files to. It will automatically create a sub-folder within the directory you choose.
    4. For the check-boxes, I suggest unselecting all, then clicking the drop down menu beside ROIs to individually select the ROI that you want to analyze
4. Clicking export will start the conversion process and is the final step in the preprocessing pipeline

## Creating a Cell Mask

### Prerequisites

- Windows or Mac copy of CellProfiler downloaded
- Have a copy of the CellMaskGeneration.pipeline
- Single Channel TIFFs of each marker from the ROI that you want to analyze

### Steps to follow

1. Open CellProfiler
2. Drag and drop the CellMaskGeneration.pipeline file (or click import pipeline from the file menu)
3. In the “Images” section, drag and drop your folder with the single channel TIFFs
4. In the “NamesAndTypes” section, click the update button to allow the program to search through the files for the two DNA markers that we will use for our segmentation mask
5. The first module that will require some customization is the ImageMath module
    1. this is where you will determine the multiplication factor that yields the most amount of identifiable nuclei. This is a fine balance between making some nuclei brighter without making some others too bright and requires trial and error.
    2. To determine if the value you have chosen is appropriate, start test mode in the bottom left, and click step to visualize the nuclei.
    3. Clicking next once more will denoise the image to remove hot pixels in the background
    4. Clicking next will start the segmentation of the nuclei. This is where you will need to use the zoom tool on the pop-up window to see if you nuclei are being segmented correctly. Oversegmentation will overestimate the cell count.
6. After tinkering with the settings of the pipeline, you can exit test mode. Then click the “SaveImages” section to select a folder to save your cell mask to. this will generate one TIFF file named “CellMask.tiff” that needs to be dragged into the folder containing the single channel tiffs for your ROI.
7. Clicking Run will start the pipeline

> Note: You will have to do this individually for each of the ROIs. Make sure you put the correct CellMask.tiff file into correct folder as it is critical for downstream analysis

## Extracting Single Cell Information

### Prerequisites

- Single channel TIFFs of each marker from the ROI that you want to analyze
    - A Cell Mask from CellProfiler must be in this same folder
- Windows or Mac copy of MATLAB2023b
- HistoCAT installed on the MATLAB path from the Shapiro Lab
    - From ([https://github.com/SchapiroLabor/histoCAT](https://github.com/SchapiroLabor/histoCAT)), click the large green code button and download a zip file.
    - Extract the files in the folder, and put it in a folder in documents
    - Open MATLAB, in the HOME tab, click “Set Path” under the ENVIRONMENT section
    - Click “add with subfolders” and highlight the folder containing the HistoCAT code, then click open.
    - Then click save at the bottom of the window

### Steps to Follow

1. Open MATLAB2023b
2. To run histoCAT, you must type histoCAT into the command window of MATLAB
3. In the top left, click Load → Load Samples
4. In the current folder input box, type the directory of the folder containing your single channel TIFF images (e.g. /Users/imcfacility/Documents/jyot)
5. Click the folder containing the TIFFs → click add → click done

> It is important to note, that during testing, doing batch uploads of multiple samples at once was causing histoCAT to crash. It is best to do 1 sample at a time.

6. for the following prompts, click okay (these are the methods that histoCAT uses to extract single cell information. A pixel expansion of 4 means it creates a cell border radius 4 pixels away from the edge of the nucleus that was detected from the mask stage. We do no want to transform the data at this stage either, as we want to keep the raw values)
7. After processing the single cell information, histoCAT will ask you for a location to save the gates that you will create.
8. The files and markers will populate their respective rows
9. On the top left, click save → gate as csv (optionally, you can also save as fcs for external analysis using flowJo or other software)

> Note: It is best to save all csv files into one folder called data for downstream analysis

## Visualizing Single Cell Data

This step of the workflow is highly customizable. To make it simpler for the user, I found it best to use the steps listed below.

### Prerequisites

- Windows or Mac copy of R-Studio
- .csv files of each sample that you want to analyze
- Create 3 Folders called data, processing, and metadata in the same directory

### Steps to follow

1. Store all your .csv files in a folder labeled as “data”
2. In your metadata folder, create a .csv file with the following structure

|Filename|Sample|Group|Cells per sample|
|---|---|---|---|

> The filename should match exactly that of the .csv file. The cells per sample can be found by opening the .csv file and checking the number of cells present

3. Open R-Studio and set the working directory to your processing folder using the following code.

```
### Replace PATH_TO_PROCESSING_FOLDER with actual path 
### (e.g /Users/jyot/Documents/IMCTraining/processing)

a <- r"(PATH_TO_PROCESSING-FOLDER)"
setwd(a)
```

> Now the following is a workflow that has been adapted from ([https://immunedynamics.io/spectre/simple-discovery/#Introduction](https://immunedynamics.io/spectre/simple-discovery/#Introduction))

### Loading Spectre package and setting directories

```
    ### Load libraries
        library(Spectre)
        Spectre::package.check()    # Check that all required packages are installed
        Spectre::package.load()     # Load required packages

    ### Set PrimaryDirectory
        getwd()
        PrimaryDirectory <- getwd()
        PrimaryDirectory
        
    ### Set 'input' directory
        setwd(PrimaryDirectory)
        dir.create("data", showWarnings = FALSE)
        setwd("data")
        InputDirectory <- getwd()
        setwd(PrimaryDirectory)
        
    ### Set 'metadata' directory
        setwd(PrimaryDirectory)
        dir.create("metadata", showWarnings = FALSE)
        setwd("metadata")
        MetaDirectory <- getwd()
        setwd(PrimaryDirectory)

    ### Create output directory
        setwd(PrimaryDirectory)
        dir.create("Output_Spectre", showWarnings = FALSE)
        setwd("Output_Spectre")
        OutputDirectory <- getwd()
        setwd(PrimaryDirectory)
```

### Importing Data and merging with Metadata

```
    ### Import data
        setwd(InputDirectory)
        list.files(InputDirectory, ".csv")
        data.list <- Spectre::read.files(file.loc = InputDirectory,
                                         file.type = ".csv",
                                         do.embed.file.names = TRUE)

    ### Merge data
        cell.dat <- Spectre::do.merge.files(dat = data.list)
        cell.dat

    ### Read in metadata  
        setwd(MetaDirectory)
        meta.dat <- fread("sample.details.csv")
        meta.dat
```

### Arcsinh Transform

```
    ### Arcsinh transformation
        as.matrix(names(cell.dat))

       
    ### Change the numbers in the bracket to match the columns that have relevant markers
        to.asinh <- names(cell.dat)[c(1:9)]
        to.asinh

        cofactor <- 15

        cell.dat <- do.asinh(cell.dat, to.asinh, cofactor = cofactor)
        transformed.cols <- paste0(to.asinh, "_asinh")
```

### Metadata formatting and selection of markers and cells for analysis

```
    ### Add metadata to data.table
        meta.dat

        sample.info <- meta.dat[,c(1:3)]
        sample.info
        counts <- meta.dat[,c(2,4)]
        counts
	    cell.dat <- do.add.cols(cell.dat, "FileName", sample.info, "Filename", rmv.ext = TRUE)
        cell.dat

### View all your columns
        as.matrix(names(cell.dat))

### Change the number in the brackets to those that have _asinh behind their name
        cellular.cols <- names(cell.dat)[c(12:20)]
        as.matrix(cellular.cols)

### Do the same as above and change the numbers to the appropriate columns
        cluster.cols <- names(cell.dat)[c(12:20)]
        as.matrix(cluster.cols)

        exp.name <- "CNS experiment"
        sample.col <- "Sample"
        group.col <- "Group"

### Subsample targets per group
        data.frame(table(cell.dat[[group.col]]))# Check number of cells per sample.

### Check how many unique groups you have
        unique(cell.dat[[group.col]])

        sub.targets <- c(2000, 20000)# target subsample numbers from each group, must be less than total number of cells
        sub.targets
```

### Analysis Commands using SpectreR package

```
    setwd(OutputDirectory)
    dir.create("Output - clustering")
    setwd("Output - clustering")

### Change the number here to reflect the number of cluster you want to have
        cell.dat <- run.flowsom(cell.dat, cluster.cols, meta.k = 16)
        cell.dat

### Dimensionality reduction
        cell.sub <- do.subsample(cell.dat, sub.targets, group.col)
        cell.sub
        cell.sub <- run.umap(cell.sub, cluster.cols)
        cell.sub
```

### Plotting of UMAPs, Expression Heatmaps, and individual marker expression

```
### DR plots
        make.colour.plot(cell.sub, "UMAP_X", "UMAP_Y", "FlowSOM_metacluster", col.type = 'factor', add.label = TRUE)

### the following will generate an image with individual marker expression on the DR plot
        make.multi.plot(cell.sub, "UMAP_X", "UMAP_Y", cellular.cols)

### Generate an Expression heatmap to classify each group
        exp <- do.aggregate(cell.dat, cellular.cols, by = "FlowSOM_metacluster")
        make.pheatmap(exp, "FlowSOM_metacluster", cellular.cols)
```
