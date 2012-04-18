# TODO: Add comment
# 
# Author: mfuria
###############################################################################

setMethod(
  f = "initialize",
  signature = "SynapseLocationOwner",
  definition = function(.Object){
    .Object@archOwn <- new("ArchiveOwner")
    .Object
  }
)

setMethod(
  f = "storeEntity",
  signature = "SynapseLocationOwner",
  definition = function(entity){
    ## create the archive on disk (which will persist file metaData to disk)
    createArchive(entity@archOwn)
    
    ## upload the archive  file (storeFile also updates the entity)
    entity <- storeFile( ,file.path(entity@archOwn@fileCache$getCacheRoot(), entity@archOwn@fileCache$getArchiveFile()))
    entity
  }
)


setMethod(
  f = "storeFile",
  signature = signature("SynapseLocationOwner", "character"),
  definition = function(entity, filePath) {
    
    if(!file.exists(filePath))
      stop('archive file does not exist')
    
    ## make sure that the entity is up to date
    if(is.null(propertyValue(entity, "id"))){
      ## Create the LocationOwner in Synapse
      entity <- createEntity(entity)
    } else {
      ## Update the LocationOwner in Synapse just in case any other fields were changed
      ## TODO is this needed?
      entity <- updateEntity(entity)
    } 
    
    tryCatch(
      .performRUpload(entity, filePath),
      error = function(e){
        warning(sprintf("failed to upload data file, please try again: %s", e))
        return(entity)
      }
    )
    
    ## move the data file from where it is to the local cache directory
    parsedUrl <- .ParsedUrl(propertyValue(entity, 'locations')[[1]]['path'])
    destdir <- file.path(synapseCacheDir(), gsub("^/", "", parsedUrl@pathPrefix))
    destdir <- path.expand(destdir)
    
    ## set the cachRoot to the new location this method should do the right 
    ## thing. don't move if src and dest are the same. make sure there are
    ## no straggler files left behind, clean up temp directories, etc.
    entity@archOwn <- setCachRoot(entity@archOwn, destdir, cleanUp = TRUE)
  
    ## unpack the archive into it's new root directory.
    entity@archive <- unpackArchive(entity@archOwn)
    invisible(entity)
  }
)

setMethod(
  f = "downloadEntity",
  signature = "SynapseLocationOwner",
  definition = function(entity){
    ## check whether user has signed agreement
    ## euals are broken. ignore for now
#    if(!hasSignedEula(entity)){
#      if(!.promptSignEula())
#        stop(sprintf("Visit https://synapse.sagebase.org to sign the EULA for entity %s", propertyValue(entity, "id")))
#      if(!.promptEulaAgreement(entity))
#        stop("You must sign the EULA to download this dataset. Visit http://synapse.sagebase.org for more information.")
#      .signEula(entity)
#    }
    
    ## download the archive from S3
    ## Note that we just use the first location, to future-proof this we would use the location preferred
    ## by the user, but we're gonna redo this in java so no point in implementing that here right now
    archivePath = synapseDownloadFile(url = locations[[1]]['path'], checksum = propertyValue(entity, "md5"))
    
    ## instantiate the FileCache object
    entity@archOwn <- getFileCache(archivePath)
    
    ## unpack the archive
    unpackArchive(entity@archOwn)
    
    entity
  }
)

setMethod(
  f = "addFile",
  signature = signature("SynapseLocationOwner", "character", "character"),
  definition = function(entity, file, path){
    entity@archOwn <- addFile(entity@archOwn, file, path)
    invisible(entity)
  }
)

setMethod(
    f = "addFile",
    signature = signature("SynapseLocationOwner", "character", "missing"),
    definition = function(entity, file){
      entity@archOwn <- addFile(entity@archOwn, file)
      invisible(entity)
    }
)

setMethod(
    f = "moveFile",
    signature = signature("SynapseLocationOwner", "character", "character"),
    definition = function(entity, src, dest){
      entity@archOwn <- moveFile(entity@archOwn, src, dest)
      invisible(entity)
    }
)

setMethod(
    f = "deleteFile",
    signature = signature("SynapseLocationOwner", "character"),
    definition = function(entity, file){
      entity@archOwn <- deleteFile(entity@archOwn, file)
      invisible(entity)
    }
)

names.SynapseLocationOwner <-
    function(x)
{
  c("objects", "cacheDir", "files")
}


setMethod(
    f = "[",
    signature = "SynapseLocationOwner",
    definition = function(x, i, j, ...){
      if(length(as.character(as.list(substitute(list(...)))[-1L])) > 0L || !missing(j))
        stop("incorrect number of subscripts")
      if(is.numeric(i)){
        if(any(i > length(names(x))))
          stop("subscript out of bounds")
        i <- names(x)[i]
      }else if(is.character(i)){
        if(!all(i %in% names(x)))
          stop("undefined objects selected")
      }else{
        stop(sprintf("invalid subscript type '%s'", class(i)))
      }
      retVal <- lapply(i, function(i){
            if(i=="objects"){
              retVal <- x@archOwn@objects
            }else if(i == "cacheDir"){
              retVal <- cacheDir(x@archOwn)
            }else if(i == "files"){
              retVal <- files(x@archOwn)
            }else{
              retVal <- NULL
            }
          }
      )
      names(retVal) <- i
      retVal
    }
)

setMethod(
    f = "[[",
    signature = "SynapseLocationOwner",
    definition = function(x, i, j, ...){
      if(length(as.character(as.list(substitute(list(...)))[-1L])) > 0L || !missing(j))
        stop("incorrect number of subscripts")
      if(length(i) > 1)
        stop("subscript out of bounds")
      x[i][[1]]
    }
)

setMethod(
    f = "$",
    signature = "SynapseLocationOwner",
    definition = function(x, name){
      x[[name]]
    }
)

setMethod(
  f = "show",
  signature = "SynapseLocationOwner",
  definition = function(object){
    cat('An object of class "', class(object), '"\n', sep="")
    
    cat("Synapse Entity Name : ", properties(object)$name, "\n", sep="")
    cat("Synapse Entity Id   : ", properties(object)$id, "\n", sep="")
    
    if (!is.null(properties(object)$parentId))
      cat("Parent Id           : ", properties(object)$parentId, "\n", sep="")
    if (!is.null(properties(object)$type))
      cat("Type                : ", properties(object)$type, "\n", sep="")
    if (!is.null(properties(object)$versionNumber)) {
      cat("Version Number      : ", properties(object)$versionNumber, "\n", sep="")
      cat("Version Label       : ", properties(object)$versionLabel, "\n", sep="")
    }
    
    obj.msg <- summarizeObjects(object)
    if(!is.null(obj.msg)){
      cat("\n", obj.msg$count,":\n", sep="")
      cat(obj.msg$objects, sep="\n")
    }
    
    files.msg <- summarizeCacheFiles(object)
    if(!is.null(files.msg))
      cat("\n", files.msg$count, "\n", sep="")
    if(!is.null(propertyValue(object,"id"))){
      cat("\nFor complete list of annotations, please use the annotations() function.\n")
      cat(sprintf("To view this Entity on the Synapse website use the 'onWeb()' function\nor paste this url into your browser: %s\n", object@synapseWebUrl))
    }
  }
)

setMethod(
  f = "summarizeObjects",
  signature = "SynapseLocationOwner",
  definition = function(entity){
    msg <- NULL
    if(length(entity$objects  ) > 0){
      msg$count <- sprintf("loaded object(s)")
      objects <- objects(entity$objects)
      classes <- unlist(lapply(objects, function(object){paste(class(entity$objects[[object]]), collapse=":")}))
      msg$objects <- sprintf('[%d] "%s" (%s)', 1:length(objects), objects, classes)
    }
    msg
  }
)

setMethod(
  f = "summarizeCacheFiles",
  signature = "SynapseLocationOwner",
  definition = function(entity){
    ## if Cached Files exist, print them out
    msg <- NULL
    if(length(entity$cacheDir) != 0){
      msg$count <- sprintf('%d File(s) cached in "%s"', length(entity$files), entity$cacheDir)
      if(length(entity$files) > 0)
        msg$files <- sprintf('[%d] "%s"',1:length(entity$files), entity$files)
    }
    msg
  }
)

setMethod(
  f = "loadObjectsFromFiles",
  signature = "SynapseLocationOwner",
  definition = function(owner){
    owner@archOwn <- loadObjectsFromFiles(owner@archOwn)
    invisible(owner)
  }
)

#setMethod(
#  f = "attach",
#  signature = "LocationOwner",
#  definition = function (what, warn.conflicts = TRUE) {
#    
#    if(missing(name))
#      name = getPackageName(what@location@objects)
#    what <- what@location@objects
#    attach (what, pos = pos, name = name, warn.conflicts) 
#  }
#)



