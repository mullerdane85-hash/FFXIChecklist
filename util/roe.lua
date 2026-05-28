local roe_util = {}
local roemap = require('../maps/roe_objectives')
local roe_exclusions = require('../maps/roe_objectives_extra')
local roe_data = ''

roe_util.log_roe = function(roe_data)
	local output_list = {}
	local total, complete = 0,0
	local hiddentotal, hiddencomplete = 0,0
	local hiddenmap = roe_exclusions.hidden
	if trackermenusettings.showexcluded then hiddenmap = S{} end
	local keys = L(roemap:keyset()):sort()
	for key in keys:it() do
		total = total+1
		local completion = false
		if (roe_exclusions.excluded[key] or hiddenmap[key]) then hiddentotal = hiddentotal+1 end
		if util.has_bit(roe_data, key) then
			complete = complete+1
			completion = true
			if (roe_exclusions.excluded[key] or hiddenmap[key]) then hiddencomplete = hiddencomplete+1 end
		end
		if (not roe_exclusions.excluded:contains(key)) and (not hiddenmap:contains(key))  then
			table.insert(output_list, util.list_item(nil, roemap[key].name, completion))
		end
	end
	-- do only crafting shields
	for name, roelist in pairs(roe_exclusions.shields) do
		total = total+1
		local tiercomplete = 0
		local completion = false
		for key in pairs(roelist) do
			if util.has_bit(roe_data, key) then
				tiercomplete = 1
				completion = true
			end
		end
		complete = complete + tiercomplete
		table.insert(output_list, util.list_item(nil, name, completion))
	end
	playertracker.roe_completed = complete - hiddencomplete
	playertracker.roe_total = total - hiddentotal
	tab_logs.roe = {
		name = tab_logs.roe.name,
		completed = complete,
		total = total,
		items = output_list
	}
	--return output_list
end

return roe_util