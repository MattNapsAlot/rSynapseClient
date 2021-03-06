## Send a post or put request to Synapse
## 
## Author: Matthew D. Furia <matt.furia@sagebase.org>
###############################################################################

.synapsePostPut <- 
  function(uri, entity, requestMethod, host = .getRepoEndpointLocation(), curlHandle = getCurlHandle(), 
    anonymous = FALSE, path = .getRepoEndpointPrefix(), opts = .getCache("curlOpts"))
{
  ## constants
  kValidMethods <- c("POST", "PUT", "DELETE")
  ## end constants
  
  if(!(requestMethod %in% kValidMethods)){
    stop("invalid request method")
  }
  
  if(!is.character(uri)){
    stop("a uri must be supplied of R type character")
  }
  
  if (missing(entity) || is.null(entity)) {
	  stop("no content for post/put")
  }
  
  if(!is.list(entity)) {
    stop("an entity must be supplied of R type list")
  }
  
  if((any(names(entity) == "") || is.null(names(entity))) && length(entity) > 0){
    stop("all entity elements must be named")
  }
  
  if(length(entity) == 0)
    entity <- emptyNamedList
  
  ## change dates to characters
  indx <- grep("date", tolower(names(entity)))
  indx <- indx[as.character(entity[indx]) != "NULL"]
  indx <- indx[names(entity)[indx] != "dateAnnotations"]
  for(ii in indx)
    entity[ii] <- as.character(entity[ii])
  
  
  ## convert integers to characters
  if(length(entity) > 0){
    for(ii in 1:length(entity)){
      if(all(checkInteger(entity[[ii]])))
        entity[[ii]] <- as.character(as.integer(entity[[ii]]))
    }
  }
  
  httpBody <- toJSON(entity)
  
  ## uris formed by the service already have their servlet prefix
  if(grepl(path, uri)) {
    uri <- paste(host, uri, sep="")
  }
  else {
    uri <- paste(host, path, uri, sep="")
  }
  
  ## Add the provenance parameter, if applicable
  step <- .getCache("currentStep")
  if(!is.null(step)) {
    if(grepl("?", uri, fixed=TRUE)) {
      uri <- paste(uri, "&stepId=", propertyValue(step, "id"), sep="")
    } else {
      uri <- paste(uri, "?stepId=", propertyValue(step, "id"), sep="")			
    }
  }
  
  ## Prepare the header. If not an anonymous request, stuff the
  ## sessionToken into the header
  header <- .getCache("curlHeader")
  if(is.null(anonymous) || !anonymous) {
    header <- switch(authMode(),
      auth = .stuffHeaderAuth(header),
      hmac = .stuffHeaderHmac(header, uri),
      stop("Unknown auth mode: %s. Could not build header", authMode())
    )		
  }
  if("PUT" == requestMethod) {
    # Add the ETag header
    header <- c(header, ETag = entity$etag)
  }
  
  if(length(path) > 1)
    stop("put", paste(length(path), path))
  ## Submit request and check response code
  d = debugGatherer()
  
  ##curlSetOpt(opts,curl=curlHandle)
  
  if(!is.null(.getCache("debug")) && .getCache("debug")) {
    message("----------------------------------")
    message("REQUEST: ", requestMethod, " ", uri)
    message("REQUEST_BODY: ", httpBody)
  }
  response <- getURL(uri, 
    postfields = httpBody, 
    customrequest = requestMethod, 
    httpheader = header, 
    curl = curlHandle, 
    debugfunction=d$update,
    .opts=opts
  )
  if(!is.null(.getCache("debug")) && .getCache("debug")) {
    message("RESPONSE_BODY:: ", response)
  }
  
  .checkCurlResponse(curlHandle, response)
  
  ## Parse response and prepare return value
  tryCatch(
    as.list(fromJSON(response)),
    error = function(e){NULL}
  )
}
