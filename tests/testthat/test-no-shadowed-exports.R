# A function that has moved to edjobs is deleted here in the same change (CLAUDE.md): a local copy defined after
# library(edjobs) masks the package's, so the pipeline, the tests or the app can run the old rule while the package
# has the new one. MT's k12_he_classification.R kept the old find_k12_new_postings() after edjobs 0.70.0 took it,
# and helper-setup.R sources that file, so MT's tests ran the old rule until 2026-11-21. This fails on any
# top-level function in the repo's own R files (root, scripts/, .github/scripts/, the app) that edjobs exports.
# The same file is in the MT and WY repos (keep them identical).

repo_function_definitions <- function(root) {
  files <- c(list.files(root, pattern = "[.]R$", full.names = TRUE),
             list.files(file.path(root, c("scripts", ".github/scripts")), pattern = "[.]R$", full.names = TRUE),
             list.files(root, pattern = "^app[.]R$", recursive = TRUE, full.names = TRUE))
  files <- unique(files[!grepl("/tests/|/[.]edjobs/|/renv/", files)])
  out <- do.call(rbind, lapply(files, function(f) {
    ex <- tryCatch(parse(f, keep.source = FALSE), error = function(e) NULL)
    nm <- unlist(lapply(ex, function(e) {
      if (is.call(e) && (identical(e[[1]], as.name("<-")) || identical(e[[1]], as.name("="))) && is.name(e[[2]]) &&
          is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))) as.character(e[[2]])
    }))
    if (length(nm)) data.frame(file = sub(paste0("^", root, "/?"), "", f), fn = nm, stringsAsFactors = FALSE)
  }))
  if (is.null(out)) data.frame(file = character(0), fn = character(0)) else out
}

test_that("no repo function masks an edjobs export", {
  defs <- repo_function_definitions(normalizePath(test_path("..", "..")))
  masked <- defs[defs$fn %in% getNamespaceExports("edjobs"), , drop = FALSE]
  expect_equal(paste(masked$file, masked$fn, sep = ": "), character(0),
               info = "delete the local copy (the package's is the one to use), or rename it if it is a different thing")
})
