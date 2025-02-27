
using JSON
using DelimitedFiles
using DataFrames
using CSV

mgravens = JSON.parsefile("nda-hce-feeder-interval.json")
lmp_template = JSON.parsefile("template_lmp.json")
cap_template = JSON.parsefile("template_capacity.json")
cp_template = JSON.parsefile("template_cp.json")

energy_prices_template = Dict(
    "LocationalMarginalPrices" => Dict(),
    "CapacityPrices" => Dict(),
    "CoincidentPeakPrices" => Dict()
    )
mgravens["EnergyPrices"] = energy_prices_template
# Note, LocationalMarginalPrices and CoincidentPeakPrices have just ONE entry in their timeseries/array object, to be overwritten and appended
#   while CapacityPrices has 12 entries already, one for each month, which should typically just be updated with new values
mgravens["EnergyPrices"]["LocationalMarginalPrices"] = lmp_template["LocationalMarginalPrices"]
mgravens["EnergyPrices"]["CapacityPrices"] = cap_template["CapacityPrices"]
mgravens["EnergyPrices"]["CoincidentPeakPrices"] = cp_template["CoincidentPeakPrices"]
# Replace string segments "_name" in the key names or values of the mgravens["EnergyPrices"] dictionary with a variable to be input
function replace_name_segments!(dict, variable)
    for (key, value) in dict
        if isa(value, Dict)
            replace_name_segments!(value, variable)
        elseif isa(value, String)
            dict[key] = replace(value, "_name" => variable)
        end
        if isa(key, String) && occursin("_name", key)
            new_key = replace(key, "_name" => variable)
            dict[new_key] = dict[key]
            delete!(dict, key)
        end
    end
end

replace_name_segments!(mgravens["EnergyPrices"], "_hce")

# # Load more custom data for example, such as load profiles and other
# load_data = CSV.read("airport_feederhead_scada.csv", DataFrame)
# loads_kw = load_data[!, "Airport_Ckt_MW_feederhead"]
# critical_loads_kw = load_data[!, "Airport_Ckt_MW_entire_microgrid"]

site_name = "hce_feeder"
# load_groups = Any["ResidentialGroup"]
# energy_consumer_names = Any["hce_residential"]
# load_forecast_names = Any["hce_residential_shape"]
subregion_name = "hce_SubRegion"
region_name = "hce_Region"
lmp_name = "lmps_hce"
capacity_prices_name = "capacityprices_hce"
cp_prices_name = "coincidentpeakprices_hce"

lmp_price = 0.1
capacity_prices_monthly = ones(12) * 0.0
cp_price_monthly = 11.0 # $11/kW-month, but must specify 12 "active" timesteps for it to charge monthly, otherwise it will just charge once yearly

# TODO write the load and lmps arrays to the nda-hce-feeder-reopt.json file

# mgravens["BasicIntervalSchedule"][load_forecast_names[1]]["EnergyConsumerSchedule.RegularTimePoints"] = []
mgravens["EnergyPrices"]["LocationalMarginalPrices"][lmp_name]["LocationalMarginalPrices.LMPCurve"]["PriceCurve.CurveDatas"] = []
for ts in 1:8760
    # Update load
    # updated_load = Dict(
    #     "RegularTimePoint.sequenceNumber"=> ts,
    #     "RegularTimePoint.value2"=> 0.0,
    #     "RegularTimePoint.value1"=> loads_kw[ts]
    #     )   
    # append!(mgravens["BasicIntervalSchedule"][load_forecast_names[1]]["EnergyConsumerSchedule.RegularTimePoints"], [updated_load])
    # Update LMP
    updated_lmp = Dict(
        "CurveData.xvalue"=> ts-1, 
        "CurveData.y1value"=> lmp_price
    )
    append!(mgravens["EnergyPrices"]["LocationalMarginalPrices"][lmp_name]["LocationalMarginalPrices.LMPCurve"]["PriceCurve.CurveDatas"], [updated_lmp])
end

#  Update capacity and coincident peak prices
global hour_count = 0
active_day_for_cp = 15
active_hour_for_cp = 14
for month in 1:12
    mgravens["EnergyPrices"]["CapacityPrices"][capacity_prices_name]["CapacityPrices.CapacityPriceCurve"]["PriceCurve.CurveDatas"][month]["CurveData.y1value"] = capacity_prices_monthly[month]
    # While CapacityPrices always get updated each month, in this case we're also updating CoincidentPeakPrices each month based on HCE billing 
    cp_hour = hour_count + active_day_for_cp * 24 + active_hour_for_cp
    updated_cp = Dict(
        "CurveData.xvalue"=> cp_hour, 
        "CurveData.y1value"=> cp_price_monthly
    )
    if month == 1
        mgravens["EnergyPrices"]["CoincidentPeakPrices"][cp_prices_name]["CoincidentPeakPrices.CoincidentPeakPriceCurve"]["PriceCurve.CurveDatas"][month] = updated_cp
    else
        append!(mgravens["EnergyPrices"]["CoincidentPeakPrices"][cp_prices_name]["CoincidentPeakPrices.CoincidentPeakPriceCurve"]["PriceCurve.CurveDatas"], [updated_cp])
    end
    global hour_count += round(Int, 30.5 * 24)
end

open("energy_prices_hce.json","w") do f
    JSON.print(f, mgravens["EnergyPrices"])
end