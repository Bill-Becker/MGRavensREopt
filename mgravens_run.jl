using JSON
using JuMP
using HiGHS
using REopt
using DotEnv
DotEnv.load!()

# This file is an example workflow script for running REopt.jl with MG-Ravens standardized .json schema
# This is how NRECA is currently running REopt.jl:
# julia --project=. mgravens_run.jl "REopt_example.json" "mgravens_out.json"
# the MG-Ravens .json schema input and output files can be accessed by ARGS[1] and ARGS[2] in the mgravens_run.jl file

# Only need the line below if calling this .jl file from within Julia, as opposed to command line executing which takes the CLI ARGS
if isempty(ARGS)
    ARGS = ["REopt_example.json", "ravens_out.json"]
end

# Load in the MG-Ravens .json schema file, which is the only user input and customized for the scenario to run
input_file_path = ARGS[1]
mgravens = JSON.parsefile(input_file_path)

# Convert MG-Ravens data schema into REopt schema
reopt_inputs = convert_mgravens_inputs_to_reopt_inputs(mgravens)

# Run REopt and get results into REopt schema dictionary
s = Scenario(reopt_inputs)
inputs = REoptInputs(s)
m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.005, "output_flag" => false, "log_to_console" => false))
m2 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.005, "output_flag" => false, "log_to_console" => false))
reopt_results = run_reopt([m1, m2], inputs)

# Convert/add/update MG-Ravens data with REopt results
# Write to output_file_path .json file (2nd argument when running this script from the command line)
update_mgravens_with_reopt_results!(reopt_results, mgravens)

output_file_path = ARGS[2]
open(output_file_path,"w") do f
    JSON.print(f, mgravens)
end


