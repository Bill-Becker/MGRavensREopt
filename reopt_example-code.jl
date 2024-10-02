using JSON

# JSON (RAVENS Schema) Example File to Access
file = "./REopt_example.json"
dict = JSON.parsefile(file)

# example parsing (& accesing data)

# first, let's access the DesignAlgorithmProperties to know which ProposedAssetOptions we want to evaluate.
proposed_assets_list = dict["DesignAlgorithmProperties"]["DesignAlgorithmProperties.ProposedEnergyProducerOptions"]
@info "ProposedEnergyProducerOptions defined inside DesignAlgorithmProperties: $(proposed_assets_list)"

# get all data for proposed asset PV1 (just the first porposed asset)
proposed_asset = dict["ProposedAssetOption"]["ProposedEnergyProducerOption"][proposed_assets_list[1]]
# @info "$(proposed_asset)" # not printed to screen due to being too large

# get the location(s) for the proposed asset
proposed_asset_site_location = dict["ProposedAssetOption"]["ProposedEnergyProducerOption"]["proposedPV1"]["ProposedAssetOption.ProposedLocations"][1]
@info "Proposed Site Location: $(proposed_asset_site_location)"

# Go to the specific proposed site
proposed_site_location = dict["ProposedSiteLocations"][proposed_asset_site_location]
proposed_site_location_area = dict["ProposedSiteLocations"][proposed_asset_site_location]["ProposedSiteLocation.availableArea"]
proposed_site_location_latandlong = dict["ProposedSiteLocations"][proposed_asset_site_location]["Location.PositionPoints"]
@info "Proposed Site Location Area: $(proposed_site_location_area)"
@info "Proposed Site Location Latitude and Longitude: $(proposed_site_location_latandlong)"

# Get the specific LoadGroup associated with the proposedsitelocations
proposed_site_loadgroup = dict["ProposedSiteLocations"][proposed_asset_site_location]["ProposedSiteLocation.LoadGroup"][1] # accessing just the first element of the ProposedSiteLocations LoadGroups
@info "Proposed site LoadGroup: $(proposed_site_loadgroup)"


# "LoadGroup.EnergyConsumers": [
#           "EnergyConsumer::'House1'",
#           "EnergyConsumer::'House2'"
#         ]

# Go to the specific LoadGroup and get the loads (or EnergyConsumers)
proposed_loadgroup_energyconsumer_1 = replace(split(dict["Group"]["LoadGroup"][proposed_site_loadgroup]["LoadGroup.EnergyConsumers"][1], "::")[2], "'" => "")
proposed_loadgroup_energyconsumer_2 = replace(split(dict["Group"]["LoadGroup"][proposed_site_loadgroup]["LoadGroup.EnergyConsumers"][2], "::")[2], "'" => "")
@info "Energy Consumer 1: $(proposed_loadgroup_energyconsumer_1)"
@info "Energy Consumer 2: $(proposed_loadgroup_energyconsumer_2)"

# Get the respective load forecasts for the EnergyConsumers
proposed_loadgroup_forecast_ec1 = replace(split(dict["PowerSystemResource"]["Equipment"]["ConductingEquipment"]["EnergyConnection"]["EnergyConsumer"][proposed_loadgroup_energyconsumer_1]["EnergyConsumer.LoadProfile"], "::")[2], "'" => "")
proposed_loadgroup_forecast_ec2 = replace(split(dict["PowerSystemResource"]["Equipment"]["ConductingEquipment"]["EnergyConnection"]["EnergyConsumer"][proposed_loadgroup_energyconsumer_2]["EnergyConsumer.LoadProfile"], "::")[2], "'" => "")

forecast_ec1 = dict["BasicIntervalSchedule"][proposed_loadgroup_forecast_ec1]
forecast_ec2 = dict["BasicIntervalSchedule"][proposed_loadgroup_forecast_ec2]

@info "Forecast 1: $(forecast_ec1)"
@info "Forecast 2: $(forecast_ec2)"

# Now, let's get the LMPs and Capacity prices (through the Region)
proposed_site_geographical_region = replace(split(dict["ProposedSiteLocations"][proposed_asset_site_location]["ProposedSiteLocation.Region"], "::")[2], "'" => "")
@info "Proposed site Geographical Region: $(proposed_site_geographical_region)"

# Let's get the EnergyPrices references from the specific Region
region_lmp_name_reference = replace(split(dict["Group"]["GeographicalRegion"][proposed_site_geographical_region]["GeographicalRegion.Regions"][1]["Regions.EnergyPrices"]["EnergyPrices.LocationalMarginalPrices"], "::")[2], "'" => "")
region_capacity_name_reference = replace(split(dict["Group"]["GeographicalRegion"][proposed_site_geographical_region]["GeographicalRegion.Regions"][1]["Regions.EnergyPrices"]["EnergyPrices.CapacityPrices"], "::")[2], "'" => "")

@info "LMP name reference: $(region_lmp_name_reference)"
@info "Capacity Prices name reference: $(region_capacity_name_reference)"

# Finally, let's us access the specific LMP and Capacity Prices data
lmp1 = dict["EnergyPrices"]["LocationalMarginalPrices"][region_lmp_name_reference]
capacityprices1 = dict["EnergyPrices"]["CapacityPrices"][region_capacity_name_reference]
