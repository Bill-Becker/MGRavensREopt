using Revise
using JSON
using JuMP
using HiGHS
using REopt
using DelimitedFiles
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
    ARGS_local = ["lehigh_example_origECLoads.json", "mgravens_out_origECLoads.json"]
end

# Load in the MG-Ravens .json schema file, which is the only user input and customized for the scenario to run
input_file_path = ARGS_local[1]
mgravens = JSON.parsefile(input_file_path)

# Temporarily manipulate the lehigh_example_v1.json data for energy prices, loads, and PV production profile because they are non-sensical
# Copied the printout of named values from the lehigh_example_v1.json for overwriting values from .csv or other source from lehigh4mgs->reopt_mg0
# site_name = "proposedSite1"
# load_groups = Any["ResidentialGroup"]
# energy_consumer_names = Any["670a_residential2"]
# load_forecast_names = Any["670a_residential2_shape"]
# subregion_name = "lehigh_SubRegion"
# region_name = "lehigh_Region"
# lmp_name = "lmps_lehigh"
# capacity_prices_name = "capacityprices_lehigh"

# Load more custom data for example, such as load profiles and other
# loads_kw = readdlm("LoadShape.csv", ',', header=false)[:,]  # Need the [:,] at the end to convert matrix to vector
# critical_loads_kw = readdlm("criticalLoadShape.csv", ',', header=false)[:,]   # NOT USED, USED 50% critical load fraction instead
# inputs_data = JSON.parsefile("julia_default.json")

# mgravens["BasicIntervalSchedule"][load_forecast_names[1]]["EnergyConsumerSchedule.RegularTimePoints"] = []
# mgravens["EnergyPrices"]["LocationalMarginalPrices"][lmp_name]["LocationalMarginalPrices.LMPCurve"]["PriceCurve.CurveDatas"] = []
# for ts in 1:8760
#     # Update load
#     updated_load = Dict(
#         "RegularTimePoint.sequenceNumber"=> ts,
#         "RegularTimePoint.value2"=> 0.0,
#         "RegularTimePoint.value1"=> loads_kw[ts]
#         )   
#     append!(mgravens["BasicIntervalSchedule"][load_forecast_names[1]]["EnergyConsumerSchedule.RegularTimePoints"], [updated_load])
#     # Update LMP
#     updated_lmp = Dict(
#         "CurveData.xvalue"=> ts-1, 
#         "CurveData.y1value"=> inputs_data["ElectricTariff"]["blended_annual_energy_rate"]
#     )
#     append!(mgravens["EnergyPrices"]["LocationalMarginalPrices"][lmp_name]["LocationalMarginalPrices.LMPCurve"]["PriceCurve.CurveDatas"], [updated_lmp])
# end
# # Update capacity prices
# for month in 1:12
#     mgravens["EnergyPrices"]["CapacityPrices"][capacity_prices_name]["CapacityPrices.CapacityPriceCurve"]["PriceCurve.CurveDatas"][month]["CurveData.y1value"] = inputs_data["ElectricTariff"]["blended_annual_demand_rate"]
# end

# open("modified_lehigh.json","w") do f
#     JSON.print(f, mgravens)
# end

# Convert MG-Ravens data schema into REopt schema
reopt_inputs = REopt.convert_mgravens_inputs_to_reopt_inputs(mgravens)

open("converted_to_reopt_inputs.json","w") do f
    JSON.print(f, reopt_inputs)
end

# Run REopt and get results into REopt schema dictionary
s = Scenario(reopt_inputs)
inputs = REoptInputs(s)
m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.005, "output_flag" => false, "log_to_console" => false))
m2 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.005, "output_flag" => false, "log_to_console" => false))
reopt_results = run_reopt([m1, m2], inputs)

# Convert/add/update MG-Ravens data with REopt results
# Write to output_file_path .json file (2nd argument when running this script from the command line)
update_mgravens_with_reopt_results!(reopt_results, mgravens)

output_file_path = ARGS_local[2]
open(output_file_path,"w") do f
    JSON.print(f, mgravens)
end


