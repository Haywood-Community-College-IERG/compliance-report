@ECHO OFF
REM The following script includes all parameters with their default values, unless it is a flag parameter that defaults to false. All flag parameters are listed below.

REM Use -files to specify that the courses are in the same folder (default: FALSE)
REM Use -leading_zeros_src to add leading zeros to the src files (default: FALSE)
REM Use -leading_zeros_dest to add leading zeros to the destination files (default: FALSE)

REM You must specify one of the following options:
REM Use -evidencefldr_in_standard to specify that the evidence folder is in the standard folder (default: FALSE)
REM Use -evidencefldr_contains_standard to specify that the evidence folder contains standard folders (default: FALSE)

REM Use -replace_spaces to replace spaces with dashes in the file names (default: FALSE)

pwsh .\ConvertFrom-Docx-To-Md.ps1 -src "" -dst "." -others_source_path "" -qep_source_path "" -standard_prefix_src "" -standard_suffix_src "" -standard_prefix_dest "Standard " -standard_suffix_dest ""  -leading_zeros_dest -evidence_folder "" -evidencefldr_in_standard -core_requirement_suffix "" -replace_spaces
