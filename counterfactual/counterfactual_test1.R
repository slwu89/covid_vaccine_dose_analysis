library(safir)
library(squire)
library(nimue)
library(data.table)
library(ggplot2)
library(parallel)
library(tidyverse)
library(countrycode)
library(furrr)
library(zoo)
library(here)

source("R/utils.R")
source("counterfactual/run_function_counterfactual.R")
source("R/plotting_utils.R")
source("counterfactual/vaccine_strategy_counterfactual.R")

target_pop <- 1e6
income_group <- c("LMIC")
hs_constraints <- "Present"
dt <- 0.5
repetition <- 1
vacc_start <- "1/1/2021"
vaccine_doses <- c(2,3)
vaccine <- "Oxford-AstraZeneca"
max_coverage <- 0.8
age_groups_covered <- 9
age_groups_covered_d3 <- c(9,5)
seeding_cases <- 10
variant_fold_reduction <- 1
dose_3_fold_increase <- 6
vacc_per_week <- 0.015
name <- "counterfactual_test1"
ab_model_infection <- c(TRUE, FALSE)

#### Create scenarios ##########################################################

scenarios <- expand_grid(income_group = income_group,
                         target_pop = target_pop,
                         hs_constraints = hs_constraints,
                         vaccine_doses = vaccine_doses,
                         vaccine = vaccine,
                         max_coverage = max_coverage,
                         age_groups_covered = age_groups_covered,
                         age_groups_covered_d3 = age_groups_covered_d3,
                         vacc_start = vacc_start,
                         dt = dt,
                         repetition = repetition,
                         seeding_cases = seeding_cases,
                         variant_fold_reduction = variant_fold_reduction,
                         dose_3_fold_increase = dose_3_fold_increase,
                         vacc_per_week = vacc_per_week,
                         ab_model_infection = ab_model_infection)

vaccine_doses <- 2
max_coverage <- 0
age_groups_covered <- 9
age_groups_covered_d3 <- 9

scenarios_counter <- expand_grid(income_group = income_group,
                                 target_pop = target_pop,
                                 hs_constraints = hs_constraints,
                                 vaccine_doses = vaccine_doses,
                                 vaccine = vaccine,
                                 max_coverage = max_coverage,
                                 age_groups_covered = age_groups_covered,
                                 age_groups_covered_d3 = age_groups_covered_d3,
                                 vacc_start = vacc_start,
                                 dt = dt,
                                 repetition = repetition,
                                 seeding_cases = seeding_cases,
                                 variant_fold_reduction = variant_fold_reduction,
                                 dose_3_fold_increase = dose_3_fold_increase,
                                 vacc_per_week = vacc_per_week,
                                 ab_model_infection = ab_model_infection)

scenarios <-scenarios_counter#rbind(scenarios, scenarios_counter)

scenarios$scenario <- 1:nrow(scenarios)
scenarios$name <- name

nrow(scenarios)

write_csv(scenarios, paste0("scenarios_", name, ".csv"))

#### Run the model #############################################################
# plan(multicore, workers = 4)
 #system.time({out <- future_pmap(scenarios, run_scenario, .progress = TRUE)})

#### OR Run the model on cluster ###############################################
#################################################################################
# to run on cluster instead
# Load functions
sources <- c("counterfactual/run_function_counterfactual.R", "R/utils.R", "counterfactual/vaccine_strategy_counterfactual.R")
src <- conan::conan_sources(c("mrc-ide/safir", "mrc-ide/squire", "mrc-ide/nimue"))
ctx <- context::context_save("context",
                             sources = sources,
                             packages = c("tibble", "dplyr", "tidyr", "countrycode", "safir", "nimue", "squire"),
                             package_sources = src)

config <- didehpc::didehpc_config(use_rrq = FALSE, use_workers = FALSE, cluster="fi--didemrchnb")
# Create the queue
run <- didehpc::queue_didehpc(ctx, config = config)
# Summary of all available clusters
# run$cluster_load(nodes = FALSE)
# Run
runs <- run$enqueue_bulk(scenarios, run_scenario, do_call = TRUE, progress = TRUE)
runs$status()
