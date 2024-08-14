param (
    [Alias("src")]
    [string]$source_path = "",  # The path to the source folder

    [Alias("dst")]
    [string]$destination_path = ".", # The path to the destination folder, default is the current folder

    # sources are individual files or they are in folders
    [Alias("f")]
    [switch]$files = $false,

    [string]$others_source_path = "", # "Other Supporting Documents",
    [string]$qep_source_path = "", # "QEP Impact Report",

    # A value of "Standard " would be "Standard 05.4" or "Standard 5.4"
    [string]$standard_prefix_src = "",           # "Standard",
    # A value of "_narrative" would be "05.4_narrative" or "5.4_narrative"
    [string]$standard_suffix_src = "", # ""
    # Do the standards have leading zeros? Like "05.4" or "5.4"
    [switch]$leading_zeros_src = $false,

    [string]$standard_prefix_dest = "Standard ",
    [string]$standard_suffix_dest = "",
    [switch]$leading_zeros_dest = $false,

    [string]$evidence_folder = "", # "_Artifacts"
    [switch]$evidencefldr_in_standard = $false,        # RptRoot/StandardFldr/_Artifacts?
    [switch]$evidencefldr_contains_standard = $false,   # RptRoot/_Artifacts/StandardFldr?
    [string]$core_requirement_suffix = "",            # " (CR)"

    [switch]$replace_spaces = $false,

    [switch]$debug = $false
)

$DEBUG = $debug

# There are three ways to organize the artifact files:
# 1. The artifacts are in an artifacts folder within the same folder as the standard
# 2. The artifacts are in a separate artifacts folder 
# 3. The artifacts are in a separate artifacts folder within a folder for each standard


# Global variables
$SOURCE_ROOT_PATH = $source_path
$DEST_ROOT_PATH = $destination_path
$FILES = $files 

$STANDARD_PREFIX = $standard_prefix_src
$STANDARD_SUFFIX = $standard_suffix_src
$INPUT_LEADING_ZEROS = $leading_zeros_src

$OUTPUT_STANDARD_PREFIX = $standard_prefix_dest
$OUTPUT_STANDARD_SUFFIX = $standard_suffix_dest
$OUTPUT_LEADING_ZEROS = $leading_zeros_dest

# DST_DOCS_FLDR_STR : Where the source artifacts are downloaded (within folders for each standard)
$DST_DOCS_FLDR_STR = "$DEST_ROOT_PATH/documents"

# DST_REQ_FLDR_STR : Where the converted markdown files are stored
$DST_REQ_FLDR_STR = "$DEST_ROOT_PATH/requirements"

$DST_IMAGES_FLDR_STR = "$DEST_ROOT_PATH/images"

$std_fldr_str = ""

$core_requirements = @("6.1","8.1","9.1","9.2","12.1")

$standards_numbers = @(
    "5.4",
    "6.1",
    "6.2.b", "6.2.c",
    "8.1", "8.2",
    "9.1", "9.2",
    "10.2", "10.3", "10.5", "10.6", "10.7", "10.9",
    "12.1", "12.4"
    "13.6", "13.7", "13.8",
    "14.1", "14.3", "14.4"
)

$qep = "QEP Impact Report"

$others = @("Welcome - Website", 
            "Welcome - PDF",
            "Overview",
            "Leadership", 
            "Requirements",
            "Support"
            )

$others_pdf = @("Signatures.pdf","Summary.pdf")

$standards_input = @()
$standards_output = @()

$db_groups = @(
    "EvidenceLinks",
    "ConvertBoxes",
    "ConvertEvidenceLinks",
    "ConvertDocx",
    "GetArtifacts",
    "Standards",
    "GetStdSourceFolder",
    "Welcome",
    ""
)

function dbg {
    param (
        [string]$group,
        [string]$msg
    )

    if (($group -notin $db_groups) -or !$DEBUG) {
        return
    }
    Write-Host "[$group]: $msg"
}


# For each standard, add the core requirement suffix if it is a core requirement, and add leading zeros if necessary
# Then add the standard prefix and suffix
foreach ($std in $standards_numbers) {
    # Create the input standard string
    $std_str = $std

    dbg -group "Standards" -msg "std_str (0): $std_str"

    if ($INPUT_LEADING_ZEROS) {

        # Split $std_str at the decimal point
        $std_parts = $std_str.Split(".", 2)
        dbg -group "Standards" -msg "std_parts (LZ): $std_parts, {$($std_parts[0])}, {$($std_parts[1])}"
    
        # Combine $std_parts[0] padded with 0 to 2 characters, a period, and $std_parts[1]
        $std_str = "$($std_parts[0].PadLeft(2, "0")).$($std_parts[1])"

        dbg -group "Standards" -msg "std_str (LZ): $std_str"
    }

    if ($core_requirements -contains $std) {
        $std_str = "$std_str$CORE_REQUIREMENT_SUFFIX"
        dbg -group "Standards" -msg "std_str (CR): CR=[$CORE_REQUIREMENT_SUFFIX], Str=[$std_str]"
    }

    $std_str = "$standard_prefix$std_str$standard_suffix"

    $standards_input += $std_str

    dbg -group "Standards" -msg "std_str (I): $std_str"

    # Create the output standard string
    $std_str = $std

    if ($OUTPUT_LEADING_ZEROS) {
        # Split $std_str at the decimal point
        $std_parts = $std_str.Split(".", 2)
        dbg -group "Standards" -msg "std_parts (LZ): $std_parts, {$($std_parts[0])}, {$($std_parts[1])}"
    
        # Combine $std_parts[0] padded with 0 to 2 characters, a period, and $std_parts[1]
        $std_str = "$($std_parts[0].PadLeft(2, "0")).$($std_parts[1])"

        dbg -group "Standards" -msg "std_str (LZ): $std_str"
    
    }

    $std_str = "$OUTPUT_STANDARD_PREFIX$std_str$OUTPUT_STANDARD_SUFFIX"

    $standards_output += $std_str
}


### TODO: Add parameter checks here!!!


function Get-StdSource-Folder { # ignore
    param (
        [string]$std_num,
        [string]$src_path
    )

    dbg -group "GetStdSourceFolder" -msg "std_num: $std_num, src_path: $src_path"

    if ($FILES) {
        # The standards are individual files in the path provided
        $rtn = $src_path.Replace("\", "/")
        dbg -group "GetStdSourceFolder" -msg "rtn (F): $rtn"
    } else {
        # The standards are in their own folders

        # Get a list of folders in $src_path
        $folders = Get-ChildItem -Path $src_path -Directory

        # Find the folder that contains the standard number
        $std_fldr = $folders | Where-Object { $_.Name -match $std_num }

        # Return the path to the standard folder
        $rtn = $std_fldr.FullName.Replace("\", "/")
        dbg -group "GetStdSourceFolder" -msg "rtn: $rtn"
    }

    return $rtn
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

    dbg -group "ConvertBoxes" -msg "fn: $fn"

    $text = Get-Content $fn

    $text = $text -replace "☒", '{{< fa regular check-square title="Checked box" >}}'
    $text = $text -replace "☐", '{{< fa regular square title="Unchecked box" >}}'

    # Write the modified text back to the file
    $text | Out-File $fn
}

function Convert-Tables-To-RawBlocks { # ignore
    param (
        [string]$fn
    )

    dbg -group "ConvertTablesToRawBlocks" -msg "fn: $fn"

    $text = Get-Content $fn

    $text = $text -replace "<table>", "``````{=html}`n<table>"
    $text = $text -replace "</table>", "</table>`n```````n"

    # Write the modified text back to the file
    $text | Out-File $fn
}

function Convert-Evidence-Links { # ignore
    param (
        [string]$fn,
        [string]$input_link,
        [string]$output_link
    )

    Write-Host "EvidenceLinks...replace links: $input_link with $output_link"

    # If requested, encode all spaces in the output strings as -
    if ($replace_spaces) {
        $output_link = $output_link -replace " ", "-"
        $output_link = $output_link -replace "%20", "-"
    }

    $text = Get-Content $fn

    $text = $text -replace $input_link, $output_link

    # Write the modified text back to the file
    $text | Out-File $fn
}

function Convert-Docx {
    param (
        [string]$std_num,
        [string]$std_str,
        [string]$std_fldr,
        [string]$input_file,
        [string]$output_file,
        [string]$dst_path
    )

    if (!$input_file) {
        $input_file = $std_str
    }

    Write-Host "Processing $input_file : $std_fldr"
    
    # Path to the docx file for the standard
    $std_docx_path = "$std_fldr/$input_file.docx"

    # Path to the resultant markdown file and images path for the standard
    $std_md_path = "$dst_path/$output_file.qmd"
    $std_img_path = "$DST_IMAGES_FLDR_STR/$output_file"

    # Make sure image path exists
    if (!(Test-Path $std_img_path)) {
        Write-Host "...creating $std_img_path"
        [void](New-Item -ItemType Directory -Force -Path $std_img_path)
    }

    Write-Host "...converting $std_docx_path to $std_md_path with images in $std_img_path"
    # Call pandoc to convert the docx file to markdown
    # Must include multi-line tables and remove grid tables to ensure proper conversion of tables and to 
    #     allow custom-styles within tables 
    $std_docx_path = $std_docx_path -replace "\\", "/"
    $std_md_path = $std_md_path -replace "\\", "/"
    $std_img_path = $std_img_path -replace "\\", "/"
    Convert-Pandoc -inp "$std_docx_path" -output $std_md_path -from "docx+styles" -to "markdown+multiline_tables-grid_tables" -extractmedia "'$std_img_path'"

    # In the markdown file, replace all instances of ☒ with 
    #     {{< fa regular square-check title="Checked box" >}} and all instances
    #     of ☐ with {{< fa regular square title="Unchecked box" >}}
    if ($PSVer -lt 6) {
        Write-Host "...replace checkboxes with FontAwesome icons"
    } else {
        Write-Host "...replace ☒ and ☐ with FontAwesome icons"
    }
    Convert-Boxes -fn $std_md_path

    Convert-Tables-To-RawBlocks -fn $std_md_path

    $text = Get-Content $std_md_path

    # Replace URL characters like %20 in the file
    $text = $text -replace "%20", " "
    $text = $text -replace "%28", "("
    $text = $text -replace "%29", ")"
    $text = $text -replace "%2C", ","
    $text = $text -replace "%2D", "-"
    $text = $text -replace "%2E", "."
    $text = $text -replace "%2F", "/"
    $text = $text -replace "%3A", ":"
    $text = $text -replace "%3B", ";"
    $text = $text -replace "%3C", "<"
    $text = $text -replace "%3D", "="
    $text = $text -replace "%3E", ">"
    $text = $text -replace "%3F", "?"
    $text = $text -replace "%40", "@"
    $text = $text -replace "%5B", "["
    $text = $text -replace "%5C", "\"
    $text = $text -replace "%5D", "]"
    $text = $text -replace "%5E", "^"
    $text = $text -replace "%5F", "_"
    $text = $text -replace "%60", "``"
    $text = $text -replace "%7B", "{"
    $text = $text -replace "%7C", "|"
    $text = $text -replace "%7D", "}"
    $text = $text -replace "%7E", "~"

    # Write the modified text back to the file
    $text | Out-File $std_md_path
    
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
            dbg -group "Artifacts" -msg "...skipping folder $src_fldr_str/$_.Name"
            continue
        }

        $art_file_path_src = "$src_fldr_str/$_"

        # if replace_spaces is true, then replace spaces with dashes for the dst file
        if ($replace_spaces) {
            $dst_file = $_ -replace " ", "-"
        } else {
            $dst_file = $_
        }

        $art_file_path_dst = "$dst_fldr_str/$dst_file"

        dbg -group "Artifacts" -msg "...copy $art_file_path_src into $art_file_path_dst"
        Copy-Item -Path $art_file_path_src -Destination $art_file_path_dst
    }
}

# Make sure all the main destination folders exist
$folders = $DST_REQ_FLDR_STR, $DST_DOCS_FLDR_STR, $DST_IMAGES_FLDR_STR 

foreach ($folder in $folders) {
    if ($folder -and !(Test-Path $folder)) {
        [void](New-Item -ItemType Directory -Force -Path $folder)
    }
}

# Get number of standards to process
$std_count = $standards_numbers.Length

Write-Host "Processing $std_count standards"

# For each standard, convert the docx file to markdown
for ($i = 0; $i -lt $std_count; $i++) {
    # The standard number is used to find the main standard folder and the evidence folder
    # It is just a number like 5.4 or 10.2
    $std_num = $standards_numbers[$i]
    # Lookup the standard string from standards for the standard number std_num
    # This is the name of the file
    # It is like "Standard 5.4_narrative" or "Standard 10.2_narrative"
    $std_str = $standards_input[$i]

    $std_fldr_str = Get-StdSource-Folder -std_num $std_num -src_path $SOURCE_ROOT_PATH

    $output_standard_number = $standards_output[$i]

    $output_file = $output_standard_number

    # Rename the markdown file to replace spaces with dashes
    if ($replace_spaces) {
        $output_file = $output_file -replace " ", "-"
    }

    dbg "Standards", "output_file: $output_file"

    Convert-Docx -std_num $std_num -std_str $std_str -std_fldr $std_fldr_str -output_file $output_file -dst_path $DST_REQ_FLDR_STR

    # If all the files are in the same folder, then we will move all the artifacts later
    if (!$files) {
        # Only get the artifacts if the folder is a Standard, not the QEP or Other Supporting Documents
        # Get the evidence folder for the standard
        if ($evidencefldr_in_standard) {
            $artifacts_src_fldr_str = "$std_fldr_str/$evidence_folder"
        } elseif ($evidencefldr_contains_standard) {
            $artifacts_src_fldr_str = Get-StdSource-Folder -std_num $std_num -src_path "$SOURCE_ROOT_PATH/$evidence_folder"
        } else {
            $artifacts_src_fldr_str = "$SOURCE_ROOT_PATH/$evidence_folder"
        }

        # Now set the _Artifacts destination folder
        $artifacts_dst_fldr_str = "$DST_DOCS_FLDR_STR/$output_file"

        Write-Host "Copying artifacts from $artifacts_src_fldr_str to $artifacts_dst_fldr_str"
        
        Get-Artifacts -src_fldr_str $artifacts_src_fldr_str -dst_fldr_str $artifacts_dst_fldr_str

        # We want to replace the links in the markdown files to point to the correct location now that it has been moved.
        # The SOURCE_ROOT_PATH is the path to the root folder where the evidence folder is located
        # We want to remove this path from the $artifact_src_fldr_str variable to reduce that variable to just the standards evidence folder
        $remove_part1 = "$SOURCE_ROOT_PATH/$evidence_folder/"
        $remove_part2 = [IO.Path]::GetFullPath($remove_part1).Replace("\", "/").Replace($remove_part1, "")
        # Make sure the slashes are all forward slashes
        $artifacts_src_fldr_str = $artifacts_src_fldr_str.Replace("\", "/")
        $artifacts_src_fldr_str = $artifacts_src_fldr_str.Replace($remove_part1, "")
        if ($remove_part2 -ne "") {
            $artifacts_src_fldr_str = $artifacts_src_fldr_str.Replace($remove_part2, "")
        }

        #if ($replace_spaces) {
        #    $artifacts_src_fldr_str = $artifacts_src_fldr_str -replace " ", "-"
        #}

        Write-Host "...replace links: $artifacts_src_fldr_str with $output_file"
        Convert-Evidence-Links -fn "$DST_REQ_FLDR_STR/$output_file.qmd" -input_link $artifacts_src_fldr_str -output_link $output_file

        # Now convert the output to UTF8 without BOM for v5. v6+ is already correct.
        if ($PSVer -lt 6) { 
            $text = Get-Content "$DST_REQ_FLDR_STR/$output_file.qmd"
            [IO.File]::WriteAllLines("$DST_REQ_FLDR_STR/$output_file.qmd", $text)
        }

    }
}

# If the source is individual files, then all the artifacts are in the same folder
if ($files) {

    # Now get the _Artifacts folder
    $artifacts_src_fldr_str = "$SOURCE_ROOT_PATH/$evidence_folder"
    $artifacts_dst_fldr_str = $DST_DOCS_FLDR_STR
  
    Get-Artifacts -src_fldr_str $artifacts_src_fldr_str -dst_fldr_str $artifacts_dst_fldr_str
}

Write-Host "Processing $qep"

if ($qep_source_path) {
    $qep_fldr = $qep_source_path
} else {
    $qep_fldr = $SOURCE_ROOT_PATH
}

$qep_output_file = $qep
# Rename the markdown file to replace spaces with dashes
if ($replace_spaces) {
    $qep_output_file = $qep_output_file -replace " ", "-"
}

Convert-Docx -std_str $qep -std_fldr $qep_fldr -dst_path $DEST_ROOT_PATH -output_file $qep_output_file

foreach ($other in $others) {
    Write-Host "Processing $other"

    if ($others_source_path) {
        $others_fldr = $others_source_path
    } else {
        $others_fldr = $SOURCE_ROOT_PATH
    }
  
    $other_output_file = $other
    # Rename the markdown file to replace spaces with dashes
    if ($replace_spaces) {
        $other_output_file = $other_output_file -replace " ", "-"
    }

    Convert-Docx -std_str $other -std_fldr $others_fldr -dst_path $DEST_ROOT_PATH -output_file $other_output_file
}

# Combine the Welcome - Website.qmd and Welcome - PDF.qmd files
if ($replace_spaces) {
    $welcome_website_md_path = "$DEST_ROOT_PATH/Welcome---Website.qmd"
    $welcome_pdf_md_path = "$DEST_ROOT_PATH/Welcome---PDF.qmd"
} else {
    $welcome_website_md_path = "$DEST_ROOT_PATH/Welcome - Website.qmd"
    $welcome_pdf_md_path = "$DEST_ROOT_PATH/Welcome - PDF.qmd"
}
$welcome_md_path = "$DEST_ROOT_PATH/index.qmd"

$welcome_website_md = Get-Content $welcome_website_md_path -Raw
$welcome_pdf_md = Get-Content $welcome_pdf_md_path -Raw

$div_start_website = "::: {.content-visible when-profile=`"website`"}`n"
$div_start_pdf = "`n::: {.content-visible when-profile=`"pdf`"}`n"
$div_end = "`n:::`n"

$welcome_md = $div_start_website, $welcome_website_md, $div_end, $div_start_pdf, $welcome_pdf_md, $div_end

Write-Host "Creating index.qmd from $welcome_website_md_path and $welcome_pdf_md_path"

if ($PSVer -lt 6) { 
    [IO.File]::WriteAllLines($welcome_md_path, $welcome_md)
} else {
    $welcome_md | Out-File $welcome_md_path
}

foreach ($other in $others_pdf) {
    Write-Host "Processing $other"

    if ($others_source_path) {
        $others_fldr = $others_source_path
    } else {
        $others_fldr = $SOURCE_ROOT_PATH
    }
  
    $other_output_file = $other
    # Rename the markdown file to replace spaces with dashes
    if ($replace_spaces) {
        $other_output_file = $other_output_file -replace " ", "-"
    }

    # Copy the PDF file specified in $other located in the $others_fldr to the destination $other_output_file
    Copy-Item -Path "$($others_fldr)\$($other)" -Destination $other_output_file
}
