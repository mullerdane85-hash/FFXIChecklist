local mmm_util = {}
local maps = require('../maps/moblinmazemongers')
local vouchers_unlocks = nil
local runes_unlocks = nil

mmm_util.handle_mmm_data = function(data)
	mmm_util.vouchers_unlocks = data:sub(0x04+1, 0x0B+1)
	mmm_util.runes_unlocks = data:sub(0x0C+1, 0x4B+1)
end

mmm_util.log_vouchers = function()
	if mmm_util.vouchers_unlocks==nil then return end
	local output_list = {}
	local total, obtained = 0, 0
	for id, name in pairs(maps.vouchers) do
		total = total+1
		local completion = false
		if util.has_bit(mmm_util.vouchers_unlocks, id) then
			obtained = obtained+1
			completion = true
		end
		table.insert(output_list, util.list_item(nil, name, completion))
	end
	playertracker.mmmvouchers_completed = obtained
	playertracker.mmmvouchers_total = total
	tab_logs.mmmvouchers = {
		name = tab_logs.mmmvouchers.name,
		completed = obtained,
		total = total,
		items = output_list
	}
	--return output_list
end

mmm_util.log_runes = function()
	if mmm_util.runes_unlocks==nil then return end
	local output_list = {}
	local total, obtained = 0, 0
	for id, name in pairs(maps.runes) do
		total = total+1
		local completion = false
		if util.has_bit(mmm_util.runes_unlocks, id) then
			obtained = obtained+1
			completion = true
		end
		table.insert(output_list, util.list_item(nil, name, completion))
	end
	playertracker.mmmrunes_completed = obtained
	playertracker.mmmrunes_total = total
	tab_logs.mmmrunes = {
		name = tab_logs.mmmrunes.name,
		completed = obtained,
		total = total,
		items = output_list
	}
	--return output_list
end

return mmm_util