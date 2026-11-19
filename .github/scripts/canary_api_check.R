# Pre-flight API canary: the core external APIs (IPEDS, CCD, the statewide feed, Census) for reachability and payload
# shape in a few seconds, before the full scrape. edjobs::canary_step() (0.52.0); the FIPS code and the feed (URL,
# signature words, CA bundle) are in state_config.R. `--strict` makes a failed check stop the run.
source("state_config.R")
canary_step()
