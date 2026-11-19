# Renders the weekly Rmd; if the workflow's `timeout -s INT` interrupts it, prints R's call stack to the log
# first, so the run says where it was stuck (WY, 2026-11-13). edjobs::render_with_stack() (0.50.0).
# Usage: Rscript .github/scripts/render_with_stack.R <file.Rmd>
edjobs::render_with_stack(commandArgs(TRUE)[1])
