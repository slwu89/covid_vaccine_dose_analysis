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
source("antibody_infection_model/run_function_abmodel.R")
source("R/plotting_utils.R")
source("R/vaccine_strategy.R")

name <- "rq1_lmic_abmodel_1"

target_pop <- 1e6
income_group <- c("LMIC")
hs_constraints <- "Present"
dt <- 0.5
repetition <- 1:20
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
ab_model_infection <- TRUE
strategy <- "realistic"
period_s <- c(250, 150)
t_period_l <- c(365, 200)
t_d3 <- 240

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
                         ab_model_infection = ab_model_infection,
                         period_s = period_s,
                         t_period_l = t_period_l,
                         t_d3 = t_d3) %>%
  filter((period_s == 250 & t_period_l == 365) | (period_s == 150 & t_period_l == 200)) %>%
  filter((t_d3 == 240) | (t_d3 != 240 & period_s == 250 & t_period_l == 365 & vacc_per_week == 0.015))

scenarios$scenario <- 1:nrow(scenarios)
scenarios$name <- name
scenarios$strategy <- strategy

nrow(scenarios)

write_csv(scenarios, paste0("antibody_infection_model/scenarios_", name, ".csv"))

#### Run the model on cluster ###############################################
# Load functions
sources <- c("antibody_infection_model/run_function_abmodel.R", "R/utils.R", "R/vaccine_strategy.R")
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

