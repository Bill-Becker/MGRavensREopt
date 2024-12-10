
using JSON

# Only need the line below if calling this .jl file from within Julia, as opposed to command line executing which takes the CLI ARGS
#ARGS = ["full_REopt_example.json", "ravens_out.json"]

input_file_path = ARGS[1]
mgravens = JSON.parsefile(input_file_path)

# Temporarily manipulate the full_REopt_example.json data for energy prices, loads, and PV production profile because they are non-sensical
#  These values look like they've been created using a random number generator 0-1
#  I've already manipulated the scalar value fields to make more sense, but need to programatically manipulate the long arrays
for ts in 1:8760
    # Make load about 1000 kW average
    mgravens["Group"]["LoadGroup"]["ResidentialGroup"]["ConformLoadGroup.ConformLoadSchedules"][1]["RegularIntervalSchedule.TimePoints"][ts]["RegularTimePoint.value1"] *= 1000
    # Make prices closer to $0.05/kWh
    mgravens["EnergyPrices"]["LocationalMarginalPrices"]["lmps1"]["LocationalMarginalPrices.LMPCurve"]["PriceCurve.CurveDatas"][ts]["CurveData.y1value"] *= 0.1
end
for month in 1:12
    # Make capacity prices closer to $5/kW/month
    mgravens["EnergyPrices"]["CapacityPrices"]["capacityprices1"]["CapacityPrices.CapacityPriceCurve"]["PriceCurve.CurveDatas"][month]["CurveData.y1value"] *= 10.0
end
    # Remove PV production factor series because hard to create a realistic one
#   so REopt will use PVWatts based on Location
pop!(mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"]["proposedPV1"], "ProposedPhotovoltaicUnitOption.GenerationProfile")

open(ARGS[2],"w") do f
    JSON.print(f, mgravens)
end

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