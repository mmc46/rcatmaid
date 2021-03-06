% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/meshes.R
\name{as.catmaidmesh}
\alias{as.catmaidmesh}
\alias{as.catmaidmesh.default}
\alias{as.catmaidmesh.hxsurf}
\alias{as.catmaidmesh.mesh3d}
\title{Convert a mesh to CATMAID format}
\usage{
as.catmaidmesh(x, ...)

\method{as.catmaidmesh}{hxsurf}(x, ...)

\method{as.catmaidmesh}{mesh3d}(x, ...)

\method{as.catmaidmesh}{default}(x, title = NULL, comment = NULL, ...)
}
\arguments{
\item{x}{A mesh object such as \code{\link[nat]{hxsurf}} or 
\code{\link[rgl]{mesh3d}} object \emph{or} a list with raw vertices (Nx3) 
and indices (Nx3).}

\item{...}{Additional fields for the CATMAID mesh object}

\item{title}{The title of the object as it will appear in the catmaid volume manager}

\item{comment}{An informative comment - e.g. how the mesh was generated.}
}
\description{
Convert a mesh to CATMAID format
}
\details{
The CATMAID mesh format is documented in the reference below and 
  typically consists of a json encoded object with fields \itemize{
  
  \item title
  
  \item mesh The mesh itself (a list of length 2)
  
  \item comments (optional)
  
  }
  
  In R we hold this list in a \code{list} object with class 
  \code{catmaidmesh}. This can then be posted to the volume manager API.
}
\references{
\url{https://github.com/catmaid/CATMAID/blob/master/sphinx-doc/source/volumes.rst}
}
\seealso{
\code{\link{catmaid_add_volume}}
}

