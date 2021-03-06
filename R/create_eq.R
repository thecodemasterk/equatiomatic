create_eq <- function(lhs,...) {
  UseMethod("create_eq", lhs)
}

#' Create the full equation
#'
#' @export
#' @keywords internal
#'
#' @param lhs A character string of the left-hand side variable extracted with
#'   \code{extract_lhs}
#' @param rhs A data frame of right-hand side variables extracted with
#'   \code{extract_rhs}.
#'
#' @inheritParams extract_eq
#' @noRd

create_eq.default <- function(model, lhs, rhs, ital_vars, use_coefs, coef_digits,
                              fix_signs, intercept, greek,
                              raw_tex) {
  rhs$final_terms <- create_term(rhs, ital_vars)

  if (use_coefs) {
    rhs$final_terms <- add_coefs(rhs, rhs$final_terms, coef_digits)
  } else {
    rhs$final_terms <- add_greek(rhs, rhs$final_terms, greek, intercept, raw_tex)
  }

  # Add error row or not in lm
  if (!use_coefs){
  error_row <- rhs[nrow(rhs) + 1,]
  error_row$term <- "error"
  error_row$final_terms <- "\\epsilon"
  rhs <- rbind(rhs, error_row)}

  list(lhs = list(lhs), rhs = list(rhs$final_terms))
}

#' @export
#' @noRd
#' @inheritParams extract_eq
create_eq.glm <- function(model, lhs, rhs, ital_vars, use_coefs, coef_digits,
                              fix_signs, intercept, greek, raw_tex) {
  rhs$final_terms <- create_term(rhs, ital_vars)

  if (use_coefs) {
    rhs$final_terms <- add_coefs(rhs, rhs$final_terms, coef_digits)
  } else {
    rhs$final_terms <- add_greek(rhs, rhs$final_terms, greek, intercept, raw_tex)
  }
  if (!is.null(model$offset)){
    rhs <- rbind(rhs, c(rep(NA, (dim(rhs)[2]-1)),
                        add_tex_ital(utils::tail(names(attr(model$terms, "dataClasses")),1), ital_vars)))
  }

  list(lhs = list(lhs), rhs = list(rhs$final_terms))
}

#' @export
#' @noRd
create_eq.polr <- function(model, lhs, rhs, ital_vars, use_coefs, coef_digits,
                           fix_signs, ...) {
  rhs$final_terms <- create_term(rhs, ital_vars)

  if (use_coefs) {
    rhs$final_terms <- add_coefs(rhs, rhs$final_terms, coef_digits)
  } else {
    rhs$final_terms <- add_greek(rhs, rhs$final_terms)
  }

  splt <- split(rhs, rhs$coef.type)
  rhs_final <- lapply(splt$scale$final_terms, function(x) {
    c(x, splt$coefficient$final_terms)
  })
  attributes(lhs) <- NULL
  list(lhs = lhs, rhs = rhs_final)
}

#' @export
#' @noRd
create_eq.clm <- function(model, lhs, rhs, ital_vars, use_coefs, coef_digits,
                          fix_signs, ...) {
  rhs$final_terms <- create_term(rhs, ital_vars)

  if (use_coefs) {
    rhs$final_terms <- add_coefs(rhs, rhs$final_terms, coef_digits)
  } else {
    rhs$final_terms <- add_greek(rhs, rhs$final_terms)
  }

  splt <- split(rhs, rhs$coef.type)
  rhs_final <- lapply(splt$intercept$final_terms, function(x) {
    c(x, splt$location$final_terms)
  })

  attributes(lhs) <- NULL
  list(lhs = lhs, rhs = rhs_final)
}


#' Create a full term w/subscripts
#'
#' @keywords internal
#'
#' @param rhs A data frame of right-hand side variables extracted with
#'   \code{extract_rhs}.
#'
#' @inheritParams extract_eq
#' @noRd

create_term <- function(rhs, ital_vars) {
  prim_escaped <- lapply(rhs$primary, function(x) {
    vapply(x, escape_tex, FUN.VALUE = character(1))
  })
  prim <- lapply(prim_escaped, add_tex_ital_v, ital_vars)

  subs_escaped <- lapply(rhs$subscripts, function(x) {
    vapply(x, escape_tex, FUN.VALUE = character(1))
  })
  subs <- lapply(subs_escaped, add_tex_ital_v, ital_vars)
  subs <- lapply(subs, add_tex_subscripts_v)

  final <- Map(paste0, prim, subs)

  vapply(final, add_tex_mult, FUN.VALUE = character(1))
}


#' Escape TeX
#'
#' Escape special TeX characters.
#'
#' Ten characters have special meaning in TeX \code{& \% $ # _ { } ~ ^ \\}.
#' This function either escapes them with \\, or in the case of the last three,
#' replaces them with special TeX macros.
#'
#' @keywords internal
#'
#' @param term A character string to escape
#'
#' @return A character string
#' @noRd

escape_tex <- function(term) {
  unescaped <- c(" ", "&", "%", "$", "#", "_", "{", "}", "~", "^", "\\")
  escaped <- c("\\ ", "\\&", "\\%", "\\$", "\\#", "\\_", "\\{", "\\}",
               "\\char`\\~", "\\char`\\^", "\\backslash ")

  # Split term into a vector of single characters
  characters <- strsplit(term, "")[[1]]

  # Go through term and replace all unescaped characters with their escaped versions
  replaced <- vapply(characters,
                     function(x) ifelse(x %in% unescaped,
                                        escaped[which(x == unescaped)],
                                        x),
                     FUN.VALUE = character(1))

  # Return the reassembled term
  paste0(replaced, collapse = "")
}


#' Wrap text in \code{\\operatorname{}}
#'
#' Add tex code to make string not italicized within an equation
#'
#' @keywords internal
#'
#' @param term A character to wrap in \code{\\operatorname{}}
#' @param ital_vars Passed from \code{extract_eq}
#'
#' @return A character string
#' @noRd

add_tex_ital <- function(term, ital_vars) {
  if (any(nchar(term) == 0, ital_vars)) {
    return(term)
  }
  paste0("\\operatorname{", term, "}")
}


#' Wrap text in \code{\\operatorname{}} (vectorized)
#'
#' Add tex code to make string not italicized within an equation for a vector
#' of strings
#'
#' @keywords internal
#'
#' @return A vector of characters
#' @noRd

add_tex_ital_v <- function(term_v, ital_vars) {
  vapply(term_v, add_tex_ital, ital_vars, FUN.VALUE = character(1))
}


#' Wrap text in \code{_{}}
#'
#' Add tex code to make subscripts for a single string
#'
#' @keywords internal
#'
#' @param term A character string to TeXify
#'
#' @return A character string
#' @noRd

add_tex_subscripts <- function(term) {
  if (any(nchar(term) == 0)) {
    return(term)
  }
  paste0("_{", term, "}")
}


#' Wrap text in \code{_{}}
#'
#' Add tex code to make subscripts for a vector of strings
#'
#' @keywords internal
#'
#' @return A vector of characters
#' @noRd

add_tex_subscripts_v <- function(term_v) {
  vapply(term_v, add_tex_subscripts, FUN.VALUE = character(1))
}


#' Add multiplication symbol for interaction terms
#'
#' @keywords internal
#' @noRd

add_tex_mult <- function(term) {
  paste(term, collapse = " \\times ")
}

#' Add a hat sign to the response variable in lm
#'
#' @keywords internal
#' @noRd

add_hat <- function(term) {
  paste0("\\widehat{", term, "}")
}



add_coefs <- function(rhs, ...) {
  UseMethod("add_coefs", rhs)
}

#' Add coefficient values to the equation
#'
#' @export
#' @keywords internal
#' @noRd

add_coefs.default <- function(rhs, term, coef_digits) {
  ests <- round(rhs$estimate, coef_digits)
  ifelse(
    rhs$term == "(Intercept)",
    paste0(ests, term),
    paste0(ests, "(", term, ")")
  )
}

#' @export
#' @keywords internal
#' @noRd

add_coefs.polr <- function(rhs, term, coef_digits) {
  ests <- round(rhs$estimate, coef_digits)
  ifelse(
    rhs$coef.type == "scale",
    paste0(ests, term),
    paste0(ests, "(", term, ")")
  )
}

#' @export
#' @keywords internal
#' @noRd

add_coefs.clm <- function(rhs, term, coef_digits) {
  ests <- round(rhs$estimate, coef_digits)
  ifelse(
    rhs$coef.type == "intercept",
    paste0(ests, term),
    paste0(ests, "(", term, ")")
  )
}

add_greek <- function(rhs, ...) {
  UseMethod("add_greek", rhs)
}

#' Adds greek symbols to the equation
#'
#' @export
#' @keywords internal
#' @noRd

add_greek.default <- function(rhs, terms, greek = "beta", intercept = "alpha",
                              raw_tex = FALSE) {
  int <- switch(intercept,
                "alpha" = "\\alpha",
                "beta" = "\\beta_{0}")
  if (raw_tex & !(intercept %in% c("alpha", "beta"))) {
    int <- intercept
  }

  ifelse(rhs$term == "(Intercept)",
         int,
         anno_greek(greek, seq_len(nrow(rhs)) - 1, terms, raw_tex)
  )
}

#' @export
#' @keywords internal
#' @noRd

add_greek.polr <- function(rhs, terms, ...) {
  rhs$idx <- unlist(lapply(split(rhs, rhs$coef.type), function(x) {
    seq_along(x$coef.type)
  }))

  ifelse(rhs$coef.type == "scale",
         anno_greek("alpha", rhs$idx),
         anno_greek("beta", rhs$idx, terms)
  )
}

#' @export
#' @keywords internal
#' @noRd

add_greek.clm <- function(rhs, terms, ...) {
  rhs$idx <- unlist(lapply(split(rhs, rhs$coef.type), function(x) {
    seq_along(x$coef.type)
  }))

  ifelse(rhs$coef.type == "intercept",
         anno_greek("alpha", rhs$idx),
         anno_greek("beta", rhs$idx, terms)
  )
}

#' Intermediary function to wrap text in `\\beta_{}`
#'
#' @keywords internal
#' @noRd

anno_greek <- function(greek, nums, terms = NULL, raw_tex = FALSE) {
  if (raw_tex) {
    out <- paste0(greek, "_{", nums,"}")
  } else {
    out <- paste0("\\", greek, "_{", nums,"}")
  }
  if (!is.null(terms)) {
    out <- paste0(out, "(", terms, ")")
  }
  out
}


#' Deduplicate operators
#'
#' Convert "+ -" to "-"
#'
#' @keywords internal
#'
#' @param eq String containing a LaTeX equation
#' @noRd

fix_coef_signs <- function(eq) {
  # Side-by-side + -
  eq_clean <- gsub("\\+ -", "- ", eq)

  # + - that spans lines
  eq_clean <- gsub("\\+ \\\\\\\\\\n&\\\\quad -",
                   "- \\\\\\\\\n&\\\\quad ",
                   eq_clean)

  eq_clean
}
