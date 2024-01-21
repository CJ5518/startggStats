--Loads the data in the json files

local json = require("lib.json");

local function loadJSONFile(filename)
	local file = io.open(filename, "r");
	--File could be nil
	if not file then return file end

	local obj = json.decode(file:read("*a"));
	file:close();
	local object2 = {};
	--Turn string indices into number indices
	for i, v in pairs(obj) do
		object2[tonumber(i)] = v;
	end
	return object2;
end

return function() return loadJSONFile("data/sets.json"), loadJSONFile("data/tournaments.json"), loadJSONFile("data/users.json") end