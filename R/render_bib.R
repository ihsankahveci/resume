# R/render_bib.R
# Provides two functions for cv.qmd:
#   print_yaml_section(file)   — renders data/*.yml as Typst resume-entry() blocks
#   print_section(bib, ...)    — renders filtered bib entries as a markdown list
#
# Requires: yaml, RefManageR
# Source once in the setup chunk; all section chunks share the state.

library(yaml)
library(RefManageR)

# Suppress the "auto-fixed" messages from ReadBib
suppressMessages({
  bib <- ReadBib("bib/cv.bib", check = FALSE)
})

# Global RefManageR print options — suppress URL/DOI/keywords from output
.bib_opts <- list(
  check.entries    = FALSE,
  bib.style        = "authoryear",
  dashed           = FALSE,
  max.names        = 99L,
  no.print.fields  = c("keywords", "abstract", "file", "url", "doi", "eprint", "eprinttype",
                        "urldate", "issn", "isbn", "note")
)

# Bold every occurrence of "Kahveci" in a formatted string.
.bold_kahveci <- function(x) {
  x <- gsub("^(Kahveci,\\s*[A-Z]\\.)", "*\\1*", x)  # first-author "Kahveci, I." format
  x <- gsub("([A-Z]\\.\\s*Kahveci)", "*\\1*", x)    # non-first-author "I. Kahveci" format
  x
}

# Format a bib entry as a Typst resume-entry() call.
# Year goes in the date column; citation text (without year) goes in title.
.format_entry_typst <- function(entry, show_year = TRUE) {
  year_actual <- as.character(entry$year %||% "")
  year        <- if (show_year) year_actual else ""

  old <- do.call(BibOptions, .bib_opts)
  on.exit(BibOptions(old))

  # Coerce standalone-title entries (no journal/booktitle) to Unpublished so the
  # title is quoted rather than italicised; journal field absent = nothing italic follows.
  entry_fmt <- entry
  if (is.null(entry$journal) && is.null(entry$booktitle)) {
    entry_fmt$bibtype <- "Unpublished"
  }
  lines <- capture.output(print(entry_fmt))
  lines <- lines[nchar(trimws(lines)) > 0]
  txt   <- paste(lines, collapse = " ")

  # Strip the year from the formatted text regardless of whether we display it
  if (nchar(year_actual) > 0) {
    txt <- sub(paste0("\\s*\\(", year_actual, "\\)\\.\\s*"), ". ", txt)
  } else {
    txt <- sub("\\s*\\(n\\.d\\.\\)\\.\\s*", ". ", txt)
  }
  txt <- .bold_kahveci(txt)

  # Escape for Typst content block: backslash and square brackets
  esc <- function(s) {
    s <- gsub("\\\\", "\\\\\\\\", s)
    s <- gsub("\\[",  "\\\\[",    s)
    s <- gsub("\\]",  "\\\\]",    s)
    s
  }

  doi <- entry$doi
  url <- entry$url
  doi_link <- if (!is.null(doi) && !is.na(doi) && nchar(trimws(doi)) > 0) {
    sprintf(' #link("https://doi.org/%s")[doi.org/%s]', doi, doi)
  } else if (!is.null(url) && !is.na(url) && nchar(trimws(url)) > 0) {
    sprintf(' #link("%s")[[PDF]]', url)
  } else ""

  note <- entry$note %||% ""
  note <- gsub("\\\\(?:mk)?bib(?:emph)?emph\\{([^}]*)\\}", "_\\1_", note, perl = TRUE)
  note <- gsub("\\\\mkbibemph\\{([^}]*)\\}", "_\\1_", note)
  note <- gsub("\\\\emph\\{([^}]*)\\}", "_\\1_", note)
  note <- gsub("\\\\&", "&", note)
  note <- trimws(note)
  desc_field <- if (nchar(note) > 0) sprintf(",\n  description: [%s]", esc(note)) else ""

  sprintf(
    '#resume-entry(\n  date: [%s],\n  title: [%s%s]%s\n)',
    year, esc(txt), doi_link, desc_field
  )
}

#' Emit bib entries as Typst resume-entry() blocks (date-left layout).
#'
#' @param bib           BibEntry object (from ReadBib at top of this file).
#' @param type          BibTeX entry type(s) to include.  NULL = all types.
#' @param include_tags  Character vector; entry must have at least one.
#' @param exclude_tags  Character vector; entries with any of these are dropped.
print_section <- function(bib,
                          type         = NULL,
                          include_tags = NULL,
                          exclude_tags = NULL,
                          show_year    = TRUE) {

  get_kw <- function(e) {
    kw <- e$keywords
    if (is.null(kw) || length(kw) == 0 || is.na(kw) || kw == "") return(character(0))
    trimws(unlist(strsplit(kw, ",\\s*")))
  }

  if (!is.null(type)) {
    type_lower <- tolower(type)
    types_all  <- sapply(bib, function(e) tolower(e$bibtype))
    bib        <- bib[types_all %in% type_lower]
  }
  if (length(bib) == 0L) return(invisible(NULL))

  if (!is.null(include_tags)) {
    keep <- sapply(bib, function(e) any(include_tags %in% get_kw(e)))
    bib  <- bib[keep]
  }
  if (length(bib) == 0L) return(invisible(NULL))

  if (!is.null(exclude_tags)) {
    drop <- sapply(bib, function(e) any(exclude_tags %in% get_kw(e)))
    bib  <- bib[!drop]
  }
  if (length(bib) == 0L) return(invisible(NULL))

  years <- sapply(bib, function(e) {
    y <- suppressWarnings(as.integer(e$year %||% NA_integer_))
    if (length(y) == 0L || is.na(y)) 0L else y
  })
  bib <- bib[order(years, decreasing = TRUE)]

  blocks <- character(length(bib))
  for (i in seq_along(bib)) {
    blocks[[i]] <- .format_entry_typst(bib[i], show_year = show_year)
  }

  cat("```{=typst}\n")
  cat(paste(blocks, collapse = "\n\n"))
  cat("\n```\n")
  invisible(NULL)
}

# Escape a string for use inside a Typst content block [...]
.typst_escape <- function(x) {
  if (is.null(x) || is.na(x) || x == "") return("")
  x <- gsub("\\\\", "\\\\\\\\", x)   # backslash
  x
}

#' Render a data/*.yml file as Typst resume-entry() blocks.
#'
#' Each top-level key in the YAML file is one CV entry with optional fields:
#'   title, location, date, description, details (list of strings)
#'
#' @param file Path to the YAML data file (relative to project root).
#' @return Invisible NULL; side-effect is cat()-ing raw Typst.
print_yaml_section <- function(file) {
  entries <- yaml::yaml.load_file(file)

  lines <- character(0)
  for (item in entries) {
    title       <- .typst_escape(item$title       %||% "")
    institution <- .typst_escape(item$institution %||% "")
    location    <- .typst_escape(item$location    %||% "")
    date        <- .typst_escape(item$date        %||% "")
    description <- .typst_escape(item$description %||% "")

    lines <- c(lines, sprintf(
      '#resume-entry(\n  title: [%s],\n  institution: [%s],\n  location: [%s],\n  date: [%s],\n  description: [%s],\n)',
      title, institution, location, date, description
    ))

    details <- item$details
    if (!is.null(details) && length(details) > 0) {
      detail_lines <- c("#resume-item[", paste0("  - ", sapply(details, .typst_escape)), "]")
      lines <- c(lines, paste(detail_lines, collapse = "\n"))
    }
  }

  # Wrap in a {=typst} raw block so Pandoc passes it through unchanged
  cat("```{=typst}\n")
  cat(paste(lines, collapse = "\n\n"))
  cat("\n```\n")

  invisible(NULL)
}

#' Render data/presentations.yml as Typst resume-presentation() blocks.
#'
#' YAML fields per entry:
#'   title, type, conference, location, date, coauthors (all optional)
print_presentations_section <- function(file) {
  entries <- yaml::yaml.load_file(file)

  blocks <- character(0)
  for (item in entries) {
    date       <- .typst_escape(item$date       %||% "")
    title      <- .typst_escape(item$title      %||% "")
    type       <- .typst_escape(item$type       %||% "")
    conference <- .typst_escape(item$conference %||% "")
    location   <- .typst_escape(item$location   %||% "")
    coauthors  <- .typst_escape(item$coauthors  %||% "")

    description <- .typst_escape(item$description %||% "")

    blocks <- c(blocks, sprintf(
      '#resume-presentation(\n  date: [%s],\n  title: [%s],\n  type: [%s],\n  conference: [%s],\n  location: [%s],\n  description: [%s],\n)',
      date, title, type, conference, location, description
    ))
  }

  cat("```{=typst}\n")
  cat(paste(blocks, collapse = "\n\n"))
  cat("\n```\n")
  invisible(NULL)
}

# Null-coalescing helper
`%||%` <- function(a, b) if (!is.null(a)) a else b
