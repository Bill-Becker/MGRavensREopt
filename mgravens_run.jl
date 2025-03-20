using Revise
using JSON
using JuMP
using HiGHS
using REopt
using DelimitedFiles
using Logging
using DotEnv
DotEnv.load!()

# This file is an example workflow script for running REopt.jl with MG-Ravens standardized .json schema
# This is how NRECA is currently running REopt.jl:
# julia --project=. mgravens_run.jl "REopt_example.json" "mgravens_out.json"
# the MG-Ravens .json schema input and output files can be accessed by ARGS[1] and ARGS[2] in the mgravens_run.jl file

# Notes about Lehigh example:
# Used data in NRECA's lehigh4mgs -> reopt_mg0 folder on the shared Google Drive
# The lehigh_example_v1.json sent by Juan was modified to just have 1 energy consumer 670a_residential2 instead of 3
# Wrote the 670a_residential2_shape profile to the loadShape.csv file data for the load forecast/profile
# The above is total load, and I used 50% for the critical load.
# Had to totally re-write the dictionaries because it was the wrong length (24 instead of 8760)
# Wrote the NRECA fixed energy price ($0.1/kWh) to the LMP profile and the  demand to the capacity prices (20/kW/month)
# NRECA is using a "wholesale_rate" of 0.034, but we don't have a separate export rate in MG-RAVENS, so we will assume the LMP is the export rate
# Changed the outage duration to 48 hours and the loadFractionCritical to 50
# Apparently REopt.jl doesn't automatically do the "four outages centered on seasonal peaks"?!? so
#   I used the REopt web tool to update the the anticipatedStartDay and anticipatedStartHour
# Removed "fixed size" for Battery
# Removed PV generation profile, to use PVWatts, and then wrote the PVWatts "GenerationProfile" back into the .json file

# Only need the line below if calling this .jl file from within Julia, as opposed to command line executing which takes the CLI ARGS
ARGS_local = deepcopy(Base.ARGS)
if isempty(ARGS_local)
    # ARGS_local = ["nda-hce-reopt-inputs.json", "nda-hce-reopt-outputs.json"]
    ARGS_local = ["lehigh_v8_shorten_lmp.json", "lehigh_v8_outputs.json"]
end

# TODO is PV production/generation profile in AC/DC, or DC/DC?

# Load in the MG-Ravens .json schema file, which is the only user input and customized for the scenario to run
input_file_path = ARGS_local[1]
mgravens = JSON.parsefile(input_file_path)

# Convert MG-Ravens data schema into REopt schema
reopt_inputs = convert_mgravens_inputs_to_reopt_inputs(mgravens)

open("converted_to_reopt_inputs_from_"*ARGS_local[1],"w") do f
    JSON.print(f, reopt_inputs)
end

# Run REopt and get results into REopt schema dictionary
s = Scenario(reopt_inputs)
inputs = REoptInputs(s)
reopt_results = Dict()
logger = SimpleLogger()  # This is helpful for 15-minute interval analysis which JuMP floods the logs with warnings
with_logger(logger) do
    m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.005, "output_flag" => false, "log_to_console" => false))
    m2 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.005, "output_flag" => false, "log_to_console" => false))
    # Have to do "global" here to overwrite the reopt_results dictionary defined outside of the with_logger loop
    global reopt_results = run_reopt([m1, m2], inputs)
end

# Convert/add/update MG-Ravens data with REopt results
# Write to output_file_path .json file (2nd argument when running this script from the command line)
# Should NOT need to use "REopt.[function] to have Revise reflect locally updated code right away (no restart)
update_mgravens_with_reopt_results!(reopt_results, mgravens)

output_file_path = ARGS_local[2]
open(output_file_path,"w") do f
    JSON.print(f, mgravens)
end


