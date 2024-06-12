param (
    [Alias("src")]
    [string]$src_path = "", # The path to the source folder

    [Alias("dst")]
    [string]$dst_path = "output", # The path to the destination folder

    # Create parameter for whether sources are individual files or they are in folders
    [Alias("f")]
    [switch]$files = $false

)

# Define strings
$USER_PROFILE = $env:USERPROFILE
$ORGANIZATION = "Haywood Community College"
$TEAM_STR = "SACSCOC Reaffirmation and 5th-Year"

#### TEAMS SITE
# The source document for the standard is stored in the main folder of the standard
$std_fldr_str = ""
# ARTIFACTS_STR : Where the source artifacts are stored within the standard folder
$ARTIFACTS_STR = "_Artifacts"

#### DOWNLOADS
# DOCX_FLDR_STR : Where the source docx files are downloaded
#$DOCX_FLDR_STR = "docx"

# DOCS_FLDR_STR : Where the source artifacts are downloaded (within folders for each standard)
$DOCS_FLDR_STR = "$dst_path/documents"

# REQ_FLDR_STR : Where the converted markdown files are stored
$REQ_FLDR_STR = "$dst_path/requirements"

$IMAGES_FLDR_STR = "$dst_path/images"

if ($src_path -eq "") {
    $src_path = "$USER_PROFILE/$ORGANIZATION"
}

#if ($files) {
#    $src_path = "$src_path/$DOCS_FLDR_STR"
#}

$stds = @(#"Standard 05.4",
          #"Standard 06.1 (CR)",
          "Standard 06.2",
          #"Standard 08.1 (CR)",
          "Standard 08.2",
          #"Standard 09.1 (CR)",
          #"Standard 09.2 (CR)",
          #"Standard 10.2",
          #"Standard 10.3",
          #"Standard 10.5",
          #"Standard 10.6",
          #"Standard 10.7",
          #"Standard 10.9",
          #"Standard 12.1 (CR)",
          #"Standard 12.4",
          #"Standard 13.6",
          #"Standard 13.7",
          #"Standard 13.8",
          #"Standard 14.1",
          "Standard 14.3"
          #"Standard 14.4"
          )

$qep_chan = "QEP Impact Report"

$others = @("Welcome - Website", 
            "Welcome - PDF",
            "Overview",
            "Leadership", 
            "Requirements",
            "Signatures", 
            "Summary", 
            "Support",
            "Documents"
            )

$others_chan = "Other Supporting Documents"

function Get-StdSource-Folder { # ignore
    param (
        [string]$std_str
    )

    if ($files) {
        return $src_path
    } else {
        return "$src_path/$TEAM_STR - $std_str - $std_str"
    }
}

function Convert-Pandoc { # ignore
    param (
        [string]$inp,
        [string]$output,
        [string]$from,
        [string]$to,
        [string]$extractmedia
    )

    $cmd = "pandoc '$inp' -o '$output' --from $from --to $to --extract-media=$extractmedia"
    Write-Host $cmd
    Invoke-Expression $cmd
}

function Convert-Boxes { # ignore
    param (
        [string]$fn
    )

    $text = Get-Content $fn

    $text = $text -replace "☒", '{{< fa regular check-square title="Checked box" >}}'
    $text = $text -replace "☐", '{{< fa regular square title="Unchecked box" >}}'

    # Write the modified text back to the file
    $text | Out-File $fn
}

function Convert-Docx {
    param (
        [string]$std_str,
        [string]$file,
        [string]$dest
    )

    if (!$file) {
        $file = $std_str
    }

    $std_fldr_str = Get-StdSource-Folder -std_str $std_str
    
    Write-Host "Processing $file : $std_fldr_str"
    
    # Path to the docx file for the standard
    $std_docx_path = "$std_fldr_str/$file.docx"

    if (!$dest) {
        $dest = $REQ_FLDR_STR
    }

    # Path to the resultant markdown file and images path for the standard
    $std_md_path = "$dest/$file.qmd"
    $std_img_path = "$IMAGES_FLDR_STR/$file"

    # Make sure image path exists
    if (!(Test-Path $std_img_path)) {
        Write-Host "...creating $std_img_path"
        [void](New-Item -ItemType Directory -Force -Path $std_img_path)
    }

    Write-Host "...converting $std_docx_path to $std_md_path with images in $std_img_path"
    # Call pandoc to convert the docx file to markdown
    # Must include multi-line tables and remove grid tables to ensure proper conversion of tables and to 
    #     allow custom-styles within tables 
    Convert-Pandoc -inp "$std_docx_path" -output $std_md_path -from "docx+styles" -to "markdown+multiline_tables-grid_tables" -extractmedia "'$std_img_path'"

    # In the markdown file, replace all instances of ☒ with 
    #     {{< fa regular square-check title="Checked box" >}} and all instances
    #     of ☐ with {{< fa regular square title="Unchecked box" >}}
    Write-Host "...replace ☒ and ☐ with FontAwesome icons"
    Convert-Boxes -fn $std_md_path

}

function Get-Artifacts { # ignore
    param (
        [string]$src_fldr_str,
        [string]$dst_fldr_str
    )

    if (!(Test-Path $dst_fldr_str)) {
        [void](New-Item -ItemType Directory -Force -Path $dst_fldr_str)
    }

    Get-ChildItem -Path $src_fldr_str -File -Name | ForEach-Object {
        if ($_.isdir) {
            Write-Host "...skipping folder $src_fldr_str/$_.Name"
            continue
        }

        $art_file_path_src = "$src_fldr_str/$_"
        $art_file_path_dst = "$dst_fldr_str/$_"

        Write-Host "...copy $art_file_path_src into $art_file_path_dst"
        Copy-Item -Path $art_file_path_src -Destination $art_file_path_dst
    }
}

$folders = $REQ_FLDR_STR, $DOCS_FLDR_STR, $IMAGES_FLDR_STR 
#$DOCX_FLDR_STR

foreach ($folder in $folders) {
    if ($folder -and !(Test-Path $folder)) {
        [void](New-Item -ItemType Directory -Force -Path $folder)
    }
}

foreach ($std in $stds) {
    $std_str = $std

    Convert-Docx -std_str $std_str

    # Only get the artifacts if the folder is a Standard, not the QEP or Other Supporting Documents
    if ($std.StartsWith("Standard") -and !$files) {

        $std_fldr_str = Get-StdSource-Folder -std_str $std_str

        # Now get the _Artifacts folder
        $artifacts_src_fldr_str = "$std_fldr_str/$ARTIFACTS_STR"
        $artifacts_dst_fldr_str = "$DOCS_FLDR_STR/$std_str"
      
        Get-Artifacts -src_fldr_str $artifacts_src_fldr_str -dst_fldr_str $artifacts_dst_fldr_str
    }
}

# If the source is individual files, then all the artifacts are in the same folder
if ($files) {

    # Now get the _Artifacts folder
    $artifacts_src_fldr_str = "$src_path/$ARTIFACTS_STR"
    $artifacts_dst_fldr_str = "$DOCS_FLDR_STR/artifacts"
  
    Get-Artifacts -src_fldr_str $artifacts_src_fldr_str -dst_fldr_str $artifacts_dst_fldr_str
}

Write-Host "Processing $qep_chan"

Convert-Docx -std_str $qep_chan -dest $dst_path

foreach ($other in $others) {
    Write-Host "Processing $other"
  
    Convert-Docx -std_str $others_chan -file $other -dest $dst_path
}

# Combine the Welcome - Website.qmd and Welcome - PDF.qmd files
$welcome_website_md_path = "$dst_path/Welcome - Website.qmd"
$welcome_pdf_md_path = "$dst_path/Welcome - PDF.qmd"
$welcome_md_path = "$dst_path/index.qmd"

$welcome_website_md = Get-Content $welcome_website_md_path
$welcome_pdf_md = Get-Content $welcome_pdf_md_path

$div_start_website = '::: {.content-visible when-profile="website"}'
$div_start_pdf = '::: {.content-visible when-profile="pdf"}'
$div_end = ':::'

$welcome_md = $div_start_website, $welcome_website_md, $div_end, $div_start_pdf, $welcome_pdf_md, $div_end

Write-Host "Creating index.qmd from $welcome_website_md_path and $welcome_pdf_md_path"
$welcome_md | Out-File $welcome_md_path