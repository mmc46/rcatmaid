#' Return the raw data for a CATMAID neuronal skeleton
#' 
#' @details Note that by default this fetches both skeleton and connector 
#'   (synapse) information.
#' @param skid single skeleton id
#' @param pid project id (default 1)
#' @param conn the \code{\link{catmaid_connection}} object
#' @param connectors Whether to fetch connector information
#' @param tags Whether to fetch tag information
#' @param raw Whether to return completely unprocessed data (when \code{TRUE}) 
#'   or to convert the nodes and connectors lists into processed data.frames 
#'   (when \code{FALSE}, the default)
#' @param ... Additional arguments passed to the \code{\link{catmaid_fetch}} 
#'   function.
#' @seealso \code{\link{read.neuron.catmaid}} to read as neuroanatomy toolbox
#'   neuron that can be plotted directly. \code{\link{catmaid_fetch}}.
#' @export
#' @examples
#' \dontrun{
#' ## ensure that you have done something like
#' # conn=catmaid_login()
#' # at least once this session to connect to the server
#' skel=catmaid_get_compact_skeleton(10418394)
#' # no connector (i.e. synapse) information
#' skel=catmaid_get_compact_skeleton(10418394, connectors = FALSE)
#' 
#' }
catmaid_get_compact_skeleton<-function(skid, pid=1L, conn=NULL, connectors = TRUE, tags = TRUE, raw=FALSE, ...) {
  path=file.path("", pid, skid, ifelse(connectors, 1L, 0L), ifelse(tags, 1L, 0L), "compact-skeleton")
  skel=catmaid_fetch(path, conn=conn, ...)
  if(isTRUE(skel[[1]]=="Exception"))
    stop("No valid neuron returned for skid: ",skid)
  names(skel)=c("nodes", "connectors", "tags")
  
  if(raw) return(skel)
  # else process the skeleton
  if(length(skel$nodes))
    skel$nodes=list2df(skel$nodes, 
                     cols=c("id", "parent_id", "user_id", "x","y", "z", "radius", "confidence"))
  
  if(length(skel$connectors))
    skel$connectors=list2df(skel$connectors, 
                            cols=c("treenode_id", "connector_id", "prepost", "x", "y", "z"))
  skel
}

list2df<-function(x, cols, use.col.names=F, return_empty_df=FALSE, ...) {
  if(!length(x)) {
    return(if(return_empty_df){
      as.data.frame(structure(replicate(length(cols), logical(0)), .Names=cols))
    } else NULL)
  }
  l=list()
  for(i in seq_along(cols)) {
    colidx=if(use.col.names) cols[i] else i
    raw_col = sapply(x, "[[", colidx)
    if(is.list(raw_col)) {
      raw_col[sapply(raw_col, is.null)]=NA
      raw_col=unlist(raw_col)
    }
    l[[cols[i]]]=raw_col
  }
  as.data.frame(l, ...)
}

#' Return skeleton ids for pre/postsynaptic partners of a set of connector_ids
#' 
#' @details Note that this returns pairwise connections between neurons. A 
#'   single synapse (i.e. connector) may have multiple connections; most 
#'   commonly a single presynaptic cell connects to multiple post-synaptic
#'   cells but many variations are possible
#' @param connector_ids Numeric ids for each connector (synapse).
#' @inheritParams catmaid_get_compact_skeleton
#' @return A data.frame with columns \itemize{
#'   
#'   \item connector_id
#'   
#'   \item pre
#'   
#'   \item post
#'   
#'   }
#' @export
#' @family connectors
catmaid_get_connectors<-function(connector_ids, pid=1, conn=NULL, raw=FALSE, ...) {
  path=paste("", pid, "connector","skeletons",sep="/")
  post_data=as.list(connector_ids)
  names(post_data)=sprintf("connector_ids[%d]", seq_along(connector_ids))
  conns=catmaid_fetch(path, body=post_data, conn=conn, ...)
  
  if(raw) return(conns)
  # else process the connector information
  if(!length(conns)) return(NULL)

  # connector_ids
  ids=as.integer(sapply(conns, "[[", 1))
  # make indiviudal data.frames of synapse info in long form
  syns=lapply(conns, function(y) expand.grid(pre=unlist(y[[2]]['presynaptic_to'], use.names = F),
                                             post=unlist(y[[2]]['postsynaptic_to'], use.names = F)))
  # now assemble that all together
  df=data.frame(connector_id=rep(ids, sapply(syns, nrow)))
  cbind(df, do.call(rbind, syns))
}


#' Return connector table for a given neuron
#' 
#' @param skids Numeric skeleton ids
#' @param direction whether to find incoming or outgoing connections
#' @param partner.skids Whether to include information about the skid of each
#'   partner neuron (NB there may be multiple partners per connector)
#' @inheritParams read.neuron.catmaid
#' @inheritParams catmaid_get_compact_skeleton
#' @return As of CATMAID v2016.10.18 this returns a data.frame with columns 
#'   \itemize{
#'   
#'   \item skid
#'   
#'   \item connector_id
#'   
#'   \item x
#'   
#'   \item y
#'   
#'   \item z
#'   
#'   \item confidence
#'   
#'   \item user_id
#'   
#'   \item partner_treenode_id
#'   
#'   \item last_modified
#'   
#'   \item partner_skid
#'   
#'   }
#'   
#'   Prior to this it returned a data.frame with columns \itemize{
#'   
#'   \item connector_id
#'   
#'   \item partner_skid
#'   
#'   \item x
#'   
#'   \item y
#'   
#'   \item z
#'   
#'   \item s
#'   
#'   \item confidence
#'   
#'   \item tags
#'   
#'   \item nodes_in_partner
#'   
#'   \item username
#'   
#'   \item partner_treenode_id
#'   
#'   \item last_modified
#'   
#'   }
#' @export
#' @examples
#' \dontrun{
#' # fetch connector table for neuron 10418394
#' ct=catmaid_get_connector_table(10418394)
#' # compare number of incoming and outgoing synapses
#' table(ct$direction)
#' 
#' ## Look at synapse location in 3d
#' # plot the neuron skeleton in grey for context
#' library(nat)
#' nopen3d()
#' plot3d(read.neurons.catmaid(10418394), col='grey')
#' # note use of nat::xyzmatrix to get xyz positions from the ct data.frame
#' # colour synapses by direction
#' points3d(xyzmatrix(ct), col=as.integer(ct$direction))
#' 
#' ## plot connected neurons in context of brain
#' nopen3d()
#' # fetch and plot brain model
#' models=catmaid_fetch("1/stack/5/models")
#' vs=matrix(as.numeric(models$cns$vertices), ncol=3, byrow = TRUE)
#' points3d(vs, col='grey', size=1.5)
#' 
#' # fetch and plot neurons
#' plot3d(read.neurons.catmaid(10418394), col='black', lwd=3)
#' points3d(xyzmatrix(ct), col=as.integer(ct$direction))
#' 
#' partner_neuron_ids=unique(na.omit(as.integer(ct$partner_skid)))
#' partner_neurons=read.neurons.catmaid(partner_neuron_ids, .progress='text', OmitFailures = TRUE)
#' plot3d(partner_neurons)
#' }
#' @family connectors
catmaid_get_connector_table<-function(skids, 
                                      direction=c("both", "incoming", "outgoing"),
                                      partner.skids=TRUE,
                                      pid=1, conn=NULL, raw=FALSE, ...) {
  direction=match.arg(direction)
  skids=catmaid_skids(skids, conn = conn, pid=pid)
  if(direction[1]=='both') {
    dfin =catmaid_get_connector_table(skids, direction='incoming', pid=pid, conn=conn, raw=raw, ...)
    dfout=catmaid_get_connector_table(skids, direction='outgoing', pid=pid, conn=conn, raw=raw, ...)
    dfin$direction="incoming"
    dfout$direction="outgoing"
    df=rbind(dfin,dfout)
    df$direction=factor(df$direction)
    return(df)
  }
  if(catmaid_version(numeric = TRUE)>="2016.09.01-77"){
    body=NULL
    paramsv=sprintf("skeleton_ids[%s]=%d",seq_len(length(skids)), skids)
    paramsv=c(paramsv, paste0("relation_type=", ifelse(direction=="incoming","postsynaptic_to","presynaptic_to")))
    params=paste(paramsv, collapse = "&")
    relpath=paste0("/", pid, "/connectors/?",params)
  } else {
    relpath=paste0("/", pid, "/connector/table/list")
    body=list(skeleton_id=skids)
    # relation_type 0 => incoming
    if(catmaid_version(numeric = TRUE)>="2016.09.01-65"){
      body$relation_type=ifelse(direction=="incoming","postsynaptic_to","presynaptic_to")
    } else {
      body$relation_type=ifelse(direction=="incoming",0L, 1L)
    }
  }
  ctl=catmaid_fetch(path=relpath, body=body, conn=conn, ...)
  catmaid_error_check(ctl)
  if(raw) return(ctl)
  # else process the connector information
  dfcolnames <- if(catmaid_version(numeric = TRUE)>="2016.09.01-77") {
    c("skid", "connector_id", "x", "y", "z", "confidence", 
      "user_id", "partner_treenode_id", "last_modified")
  } else {
    c("connector_id", "partner_skid", "x", "y", "z", "s", "confidence", 
      "tags", "nodes_in_partner", "username", "partner_treenode_id", 
      "last_modified")
  }
  df=list2df(ctl[[1]], cols = dfcolnames, return_empty_df = T, stringsAsFactors=FALSE)
  if("username"%in%names(df))
    df$username=factor(df$username)
  if(is.character(df$partner_skid))
    df$partner_skid=as.integer(df$partner_skid)
  if(partner.skids && !"partner_skid"%in%names(df)){
    # find the skids for the partners
    cdf=catmaid_get_connectors(df$connector_id, pid = pid, conn=conn, ...)
  
    if(direction=="outgoing") {
      names(cdf)[2:3]=c("skid","partner_skid")
    } else {
      names(cdf)[2:3]=c("partner_skid","skid")
    }
    df=merge(df, cdf, by=c('connector_id', 'skid'), all.x=TRUE)
  }
  df
}

#' Return tree node table for a given neuron
#' 
#' @param skid Numeric skeleton id
#' @inheritParams catmaid_get_compact_skeleton
#' @return A data.frame with columns \itemize{
#'   
#'   \item id
#'   
#'   \item type
#'   
#'   \item tags
#'   
#'   \item confidence
#'   
#'   \item x
#'   
#'   \item y
#'   
#'   \item z
#'   
#'   \item s
#'   
#'   \item r
#'   
#'   \item user
#'   
#'   \item last_modified
#'   
#'   \item reviewer (character vector with comma separated reviewer ids)
#'   
#'   }
#'   
#'   In addition two data.frames will be included as attributes: \code{reviews},
#'   \code{tags}.
#'   
#' @export
#' @examples 
#' \dontrun{
#' # get tree node table for neuron 10418394
#' tnt=catmaid_get_treenode_table(10418394)
#' # show all leaf nodes
#' subset(tnt, type=="L")
#' # table of node types
#' table(tnt$type)
#' 
#' # look at tags data
#' str(attr(tnt, 'tags'))
#' # merge with main node table to get xyz position
#' tags=merge(attr(tnt, 'tags'), tnt, by='id')
#' # label up a 3d neuron plot
#' n=read.neuron.catmaid(10418394)
#' plot3d(n, WithNodes=F)
#' text3d(xyzmatrix(tags), texts = tags$tag, cex=.7)
#' }
#' @seealso \code{\link{catmaid_get_compact_skeleton}}, 
#'   \code{\link{read.neuron.catmaid}} and \code{\link{catmaid_get_user_list}} 
#'   to translate user ids into names.
catmaid_get_treenode_table<-function(skid, pid=1, conn=NULL, raw=FALSE, ...) {
  # relation_type 0 => incoming
  tnl=catmaid_fetch(path=paste0("/", pid, "/treenode/table/",skid,"/content"),
                    conn=conn, simplifyVector = TRUE, ...)
  
  if(raw) return(tnl)
  # else process the tree node information
  # this comes in 3 separate structures:
  # treenodes, reviews, tags
  if(length(tnl)!=3)
    stop("I don't understand the raw treenode structure returned by catmaid")
  if(!length(tnl[[1]]))
    stop("There are no tree nodes for this skeleton id")
  names(tnl)=c("treenodes", "reviews", "tags")
  tnl=lapply(tnl, as.data.frame, stringsAsFactors=FALSE)
  
  colnames(tnl$treenodes)=c("id", "parent_id", "confidence", "x", "y", "z", "r",
                            "user_id", "last_modified")
  idcols=grepl("id", colnames(tnl$treenodes), fixed = TRUE)
  tnl$treenodes[idcols]=lapply(tnl$treenodes[idcols], as.integer)
  
  if(length(tnl$reviews)) {
    colnames(tnl$reviews)=c("id", "reviewer_id")
    # collapse reviewer ids into single item so that we can add one 
    # well-behaved column to the data.frame
    b=by(tnl$reviews$reviewer_id, tnl$reviews$id, paste, collapse=",")
    merged_reviews=data.frame(id=as.integer(names(b)), 
                           reviewer_id=unname(sapply(b,c)), 
                           stringsAsFactors = F)
  } else {
    merged_reviews=data.frame(id=integer(),reviewer_id=character())
    tnl$reviews=data.frame(id=integer(),reviewer_id=integer())
  }
  
  colnames(tnl$tags)=c("id", "tag")
  tnl$tags=as.data.frame(tnl$tags, stringsAsFactors = FALSE)
  tnl$tags$id=as.integer(tnl$tags$id)
  
  tndf=merge(tnl$treenodes, merged_reviews, by='id', all.x=TRUE)
  attr(tndf, 'tags')=tnl$tags
  attr(tndf, 'reviews')=tnl$reviews
  tndf
}

#' Return information about connectors joining sets of pre/postsynaptic skids
#' 
#' @details If either the \code{pre_skids} or \code{post_skids} arguments are 
#'   not specified (taking the default \code{NULL} value) then this implies
#'   there is no restriction on the pre- (or post-) synaptic partners.
#'   
#'   Each row is a unique set of pre_synaptic node, post_synaptic node, 
#'   connector_id. A rare (and usually erroneous) scenario is if the same 
#'   pre_node and post_node are present with two different connector_ids - this 
#'   would create two rows.
#' @param pre_skids,post_skids Skeleton ids in any form understood by 
#'   \code{\link{catmaid_skids}} or \code{NULL} meaning no restriction.
#' @return A data.frame with columns \itemize{
#'   
#'   \item pre_skid
#'   
#'   \item post_skid
#'   
#'   \item connector_id
#'   
#'   \item pre_node_id
#'   
#'   \item post_node_id
#'   
#'   \item connector_x
#'   
#'   \item connector_y
#'   
#'   \item connector_z
#'   
#'   \item pre_node_x
#'   
#'   \item pre_node_y
#'   
#'   \item pre_node_z
#'   
#'   \item post_node_x
#'   
#'   \item post_node_y
#'   
#'   \item post_node_z
#'   
#'   \item pre_confidence
#'   
#'   \item pre_user
#'   
#'   \item post_confidence
#'   
#'   \item post_user
#'   
#'   }
#' @export
#' @inheritParams catmaid_get_compact_skeleton
#' @family connectors
catmaid_get_connectors_between <- function(pre_skids=NULL, post_skids=NULL, 
                                           pid=1, conn=NULL, raw=FALSE, ...) {
  post_data=list()
  if(!is.null(pre_skids)){
    pre_skids=catmaid_skids(pre_skids, conn = conn, pid=pid)
    post_data[sprintf("pre[%d]", seq(from=0, along.with=pre_skids))]=as.list(pre_skids)
  }
  if(!is.null(post_skids)){
    post_skids=catmaid_skids(post_skids, conn = conn, pid=pid)
    post_data[sprintf("post[%d]", seq(from=0, along.with=post_skids))]=as.list(post_skids)
  }
  path=paste("", pid, "connector", "info", sep="/")
  conns=catmaid_fetch(path, body=post_data, conn=conn, ...)
  
  if(raw) return(conns)
  # else process the connector information
  if(!length(conns)) return(NULL)
  
  df=do.call(rbind, conns)
  colnames(df)=c("connector_id", "connector_xyz", "pre_node_id", "pre_skid", "pre_confidence", "pre_user", "pre_node_xyz", 
                 "post_node_id", "post_skid", "post_confidence", "post_user", "post_node_xyz")
  ddf=as.data.frame(df)
   xyzcols=grep("xyz",colnames(ddf), value = T)
  for(col in rev(xyzcols)){
    xyz=data.frame(t(sapply(ddf[[col]], as.numeric)))
    colnames(xyz)=paste0(sub("xyz","",col), c("x","y","z"))
    ddf=cbind(xyz, ddf)
  }
  # drop those columns
  ddf=ddf[!colnames(ddf)%in%xyzcols]
  
  # fix any columns that are still lists
  list_cols=sapply(ddf, is.list)
  ddf[list_cols]=lapply(ddf[list_cols], unlist, use.names=F)
  
  # move some columns to front
  first_cols=c("pre_skid", "post_skid", "connector_id", "pre_node_id", "post_node_id")
  ddf[c(first_cols, setdiff(colnames(ddf), first_cols))]
}
