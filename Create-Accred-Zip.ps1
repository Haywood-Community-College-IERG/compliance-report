$compress = @{            
    Path = ".\_ACCRED_SHARE\*"       
    CompressionLevel = "Fastest"
    DestinationPath = ".\ACCRED_SHARE.zip"
}                        

Compress-Archive @compress -Force