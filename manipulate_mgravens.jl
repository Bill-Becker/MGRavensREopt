
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