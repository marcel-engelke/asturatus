---@diagnostic disable-next-line: unknown-cast-variable
---@cast peripheral peripheral
---@diagnostic disable-next-line: unknown-cast-variable
---@cast turtle turtle

---@param logger logger
local function master_setup(logger)
	local _workers = {}
	---@cast _workers worker[]

	---@param label string
	---@param worker_type worker_type
	---@param worker_ch number
	local function create(label, worker_type, worker_ch)
		logger.debug("creating worker '" .. label .. "'")
		_workers[label] = {
			label = label,
			type = worker_type,
			channel = worker_ch,
			deployed = false,
		}
	end

	local function load_from_file()
		logger.trace("loading workers from file")
		-- TODO error handling
		---@diagnostic disable-next-line: undefined-global
		local f = fs.open("/workers", "r")
		---@cast f file_handle
		while true do
			local s = f.readLine()
			if not s then
				break
			end
			local m = string.gmatch(s, "([^,]+)")
			local label = m()
			local worker_type = m()
			---@cast worker_type worker_type
			local worker_ch = tonumber(m())
			---@cast worker_ch number
			create(label, worker_type, worker_ch)
		end
	end

	---@param label string
	local function get(label)
		return _workers[label]
	end

	-- Return a list of all workers (of a type)
	---@param worker_type worker_type | nil
	---@return string[]
	local function get_labels(worker_type)
		local workers = {}
		if worker_type then
			for _, w in pairs(_workers) do
				if w.type == worker_type then
					table.insert(workers, w.label)
				end
			end
		else
			for _, w in pairs(workers) do
				table.insert(workers, w.label)
			end
		end
		return workers
	end

	-- TODO turtle.getItemDetail can return all the information we need, simply pass the 'detailed' as true
	---@param label string
	local function deploy(label)
		logger.info("deploying worker '" .. label .. "'")
		-- TODO error handling

		logger.trace("placing helper chests")
		turtle.select(3)
		turtle.place()
		local chest = nil
		-- For some reason the chest cannot immediately be wrapped. Workaround: simply yield and retry
		while true do
			chest = peripheral.wrap("front")
			if chest then
				break
			end
			---@diagnostic disable-next-line: undefined-global
			sleep(1)
		end
		---@cast chest peripheral_inventory
		turtle.placeUp()

		logger.trace("placing worker chest")
		local slot = _workers[label].type == "miner" and 4 or 5
		turtle.select(slot)
		turtle.placeDown()

		logger.trace("selecting worker")
		while true do
			turtle.suckDown()
			turtle.drop()
			if chest.getItemDetail(1).displayName == label then
				logger.trace("worker found")
				break
			end
			turtle.suck()
			turtle.dropUp()
		end
		while turtle.suckUp() do
			turtle.dropDown()
		end

		logger.trace("deploying worker")
		turtle.digDown()
		turtle.select(16)
		turtle.suck()
		turtle.placeDown()
		turtle.select(1)
		turtle.dropDown(1)
		turtle.select(2)
		turtle.dropDown(1)
		_workers[label].deployed = true

		logger.trace("removing helper chests")
		turtle.select(3)
		turtle.dig()
		turtle.digUp()

		logger.trace("starting worker")
		peripheral.call("bottom", "turnOn")
		-- Yield execution to allow the worker to start
		---@diagnostic disable-next-line: undefined-global
		sleep(1)
	end

	---@param label string
	local function collect(label)
		local slot = _workers[label].type == "miner" and 4 or 5
		turtle.select(slot)
		turtle.placeUp()
		-- Have the chests go into the right slots
		turtle.select(1)
		turtle.digDown()
		_workers[label].deployed = false
		turtle.select(slot)
		turtle.dropUp()
		turtle.digUp()
	end

	return {
		create = create,
		load_from_file = load_from_file,
		get = get,
		get_labels = get_labels,
		deploy = deploy,
		collect = collect
	}
end

return {
	master_setup = master_setup
}