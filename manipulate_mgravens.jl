
using JSON
using DelimitedFiles
using DataFrames
using CSV

"""
This script is an example of how to manipulate the mgravens JSON file to add custom data such as load profiles, energy prices, etc.
This should check for the existing of all needed keys and values in the mgravens JSON file for REopt, and add them if they don't exist.
"""

# Load the existing mgravens JSON file to add/manipulate
mgravens = JSON.parsefile("nda-hce-feeder-03062025.json")

# Template files for adding keys/sections to the mgravens JSON file
algoprops_template = JSON.parsefile("template_algoprops.json")
proposedassetoption_template = JSON.parsefile("template_proposedassetoption.json")
proposedsitelocation_template = JSON.parsefile("template_proposedsitelocations.json")
region_template = JSON.parsefile("template_region.json")
loadgroup_template = JSON.parsefile("template_loadgroup.json")
lmp_template = JSON.parsefile("template_lmp.json")
cap_template = JSON.parsefile("template_capacity.json")
cp_template = JSON.parsefile("template_cp.json")
outages_template = JSON.parsefile("template_outages.json")

# Proper noun/names to be assigned to this particular use case
site_name = "proposedSite1"
load_groups = []  # e.g. ["ResidentialGroup", "IndustrialGroup"]; if empty, don't rely on LoadGroup to find EnergyConsumers and instead aggregate all EnergyConsumers
energy_consumer_names = collect(keys(mgravens["PowerSystemResource"]["Equipment"]["ConductingEquipment"]["EnergyConnection"]["EnergyConsumer"]))
# load_forecast_names = ["hce_residential_shape"]
subregion_name = "hce_SubRegion"
region_name = "hce_Region"
lmp_name = "lmps_hce"
capacity_prices_name = "capacityprices_hce"
cp_prices_name = "coincidentpeakprices_hce"
pv_prod_file = "pv_normalized_production_hce.csv"

# Replace string segments placeholder in the key names or values of the mgravens["EnergyPrices"] dictionary with a variable to be input
function replace_name_segments!(dict, placeholder, name)
    for (key, value) in dict
        if isa(value, Dict)
            replace_name_segments!(value, placeholder, name)
        elseif isa(value, String)
            dict[key] = replace(value, placeholder => name)
        end
        if isa(key, String) && occursin(placeholder, key)
            new_key = replace(key, placeholder => name)
            dict[new_key] = dict[key]
            delete!(dict, key)
        end
    end
    return dict
end

if isnothing(get(mgravens, "AlgorithmProperties", nothing))
    mgravens["AlgorithmProperties"] = algoprops_template["AlgorithmProperties"]
end


if isnothing(get(mgravens, "ProposedAssetOption", nothing))
    mgravens["ProposedAssetOption"] = proposedassetoption_template["ProposedAssetOption"]
end

# Remove PV GenerationProfile from template to use PVWatts within REopt
#delete!(mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"]["proposedPV1"], "ProposedPhotovoltaicUnitOption.GenerationProfile")
# TODO this ASSUMES 8760 profile, and currently is taking data of DC_actual / DC_rated, even though the input should be AC_actual / DC_rated
#   however, we are also underestimating the total PV because it's only based on 5 MW DC and there might be more like 6-6.7 MW AC power on the system
if !isnothing(get(mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"], "proposedPV1", nothing))
    if !isnothing(get(mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"]["proposedPV1"], "ProposedPhotovoltaicUnitOption.GenerationProfile", nothing))
        pv_gen_profile = get(mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"]["proposedPV1"]["ProposedPhotovoltaicUnitOption.GenerationProfile"], "Curve.CurveDatas", [])
        if length(pv_gen_profile) < 24
            pv_gen_profile = CSV.read(pv_prod_file, DataFrame)[!, :normalized_production]
            mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"]["proposedPV1"]["ProposedPhotovoltaicUnitOption.GenerationProfile"]["Curve.CurveDatas"] = []
            for ts in 1:8760
                updated_pv_gen = Dict(
                    "CurveData.xvalue"=> ts-1, 
                    "CurveData.y1value"=> pv_gen_profile[ts]
                )
                append!(mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"]["proposedPV1"]["ProposedPhotovoltaicUnitOption.GenerationProfile"]["Curve.CurveDatas"], [updated_pv_gen])
            end
        end
    end
end

# Manipulate other PV or Battery inputs here

if isnothing(get(mgravens, "ProposedSiteLocations", nothing))
    mgravens["ProposedSiteLocations"] = Dict(site_name => replace_name_segments!(proposedsitelocation_template["ProposedSiteLocations"][site_name], "name_SubRegion", subregion_name))
end

# Make ProposedSiteLocation.LoadGroup empty for this use case because this assumes all EnergyConsumers get aggregated
mgravens["ProposedSiteLocations"][site_name]["ProposedSiteLocation.LoadGroup"] = load_groups

# Outages - would REopt choose four outages centered around peak load?
if isnothing(get(mgravens, "OutageScenario", nothing))
    mgravens["OutageScenario"] = outages_template["OutageScenario"]
end

# TODO there may be a Group.LoadGroup in the starting .json, but it may have one entry with key="NONE" which is equivalent to omitting
if !isempty(load_groups)
    if isnothing(get(mgravens["Group"], "LoadGroup", nothing))
        mgravens["Group"]["LoadGroup"] = loadgroup_template["LoadGroup"]
    end
    loadgroup_template_generic = pop!(mgravens["Group"]["LoadGroup"], "NameGroup")
    for (i, load_group) in enumerate(load_groups)
        mgravens["Group"]["LoadGroup"][load_group] = replace_name_segments!(loadgroup_template_generic, "NameGroup", load_group)
        mgravens["Group"]["LoadGroup"][load_group]["LoadGroup.EnergyConsumers"] = ["EnergyConsumer::'"*energy_consumer_names[ec]*"'" for ec in eachindex(energy_consumer_names)]
    end
end

# The region_template.json contains both Group.SubGeographicalRegion and Group.GeographicalRegion
if isnothing(get(mgravens["Group"], "SubGeographicalRegion", nothing))
    mgravens["Group"]["SubGeographicalRegion"] = Dict(subregion_name => region_template["SubGeographicalRegion"][subregion_name])
end
if isnothing(get(mgravens["Group"], "GeographicalRegion", nothing))
    mgravens["Group"]["GeographicalRegion"] = Dict(region_name => region_template["GeographicalRegion"][region_name])
end


###   ENERGY PRICES   ###
energy_prices_template = Dict(
    "LocationalMarginalPrices" => Dict(lmp_name => Dict()),
    "CapacityPrices" => Dict(capacity_prices_name => Dict()),
    "CoincidentPeakPrices" => Dict(cp_prices_name => Dict())
    )

created_energy_prices = false
if isnothing(get(mgravens, "EnergyPrices", nothing))
    created_energy_prices = true
    # Note, LocationalMarginalPrices and CoincidentPeakPrices have just ONE entry in their template timeseries/array object, to be overwritten and appended
    #   while CapacityPrices has 12 entries already, one for each month, which should typically just be updated with new values
    mgravens["EnergyPrices"] = energy_prices_template
    mgravens["EnergyPrices"]["LocationalMarginalPrices"][lmp_name] = lmp_template["LocationalMarginalPrices"]["lmps_name"]
    mgravens["EnergyPrices"]["CapacityPrices"][capacity_prices_name] = cap_template["CapacityPrices"]["capacityprices_name"]
    mgravens["EnergyPrices"]["CoincidentPeakPrices"][cp_prices_name] = cp_template["CoincidentPeakPrices"]["coincidentpeakprices_name"]
    mgravens["EnergyPrices"] = replace_name_segments!(mgravens["EnergyPrices"], "_name", "_hce")
else
    @warn "EnergyPrices exists in mgravens.json file, so not adding any of LMP, Capacity, or CP prices"
end

if created_energy_prices
    lmp_price = 0.06 # $0.06/kWh
    capacity_prices_monthly = ones(12) * 0.0
    cp_price_monthly = 11.0 # $11/kW-month, but must specify 12 "active" timesteps for it to charge monthly, otherwise it will just charge once yearly
    active_day_for_cp = 15
    active_hour_for_cp = 17

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
end



open("nda-hce-reopt-inputs.json","w") do f
    JSON.print(f, mgravens)
end


# mgravens = JSON.parsefile("lehigh_v8_corrected.json")
# lmp_name = "lmps_lehigh"
# lmp_dict = get(mgravens["EnergyPrices"]["LocationalMarginalPrices"], lmp_name, nothing)
# lmp_list_of_dict = lmp_dict["LocationalMarginalPrices.LMPCurve"]["PriceCurve.CurveDatas"]
# wanted_list = lmp_list_of_dict[1:24]
# mgravens["EnergyPrices"]["LocationalMarginalPrices"][lmp_name]["LocationalMarginalPrices.LMPCurve"]["PriceCurve.CurveDatas"] = wanted_list
# open("lehigh_v8_shorten_lmp.json","w") do f
#     JSON.print(f, mgravens)
# end