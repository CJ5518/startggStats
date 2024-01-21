--Query users to get tournies,
--Query the tournies to get the melee singles sets
--Then take the UserIDs from the sets to build a profile on the next set of users
--And so on


local secret = require("lib.secret");
local json = require("lib.json");
local inspect = require("lib.inspect");
local argparse = require("lib.argparse");
local tournaments = {};
local users = {};
local sets = {};

users[secret.myUserID] = {id=secret.myUserID, beenQueried=false};
local outFilename = "queryout.txt";


local apiKey = secret.apiKey;
local queryLink = "https://api.start.gg/gql/alpha";

local function fileRead(filename)
	local file = io.open(filename, "r");
	local text = file:read("*a");
	file:close();
	return text;
end

--Read in the queries
local baseUserTournyQuery = fileRead("queries/userQuery.txt");
local baseTournyEventQuery = fileRead("queries/tourneyQuery.txt")
local baseEventSetQuery = fileRead("queries/eventQuery.txt")

function os.executef(command, ...)
	os.execute(string.format(command, ...));
end

function printf(str, ...)
	print(string.format(str, ...));
end



local function sendQuery(outFilename, query, operationName, variables)
	local queryJson = json.encode({["query"]=query, ["operationName"]=operationName, ["variables"]=variables});
	os.executef(
		[[curl -s -o %s -g -X POST -H "Content-Type: application/json" -H "Authorization: Bearer %s" -d '%s' %s]],
		outFilename, apiKey, queryJson, queryLink
	);
	return fileRead(outFilename);
end

local function queryErrorLoopBasic(wayToGetStringResFunc, getTotalPageNum)
	local queryObjs = {};

	for page = 1, 500 do
		
		local stringRes, obj;
		local errors = 0;
		while true do
			stringRes = wayToGetStringResFunc(page);
			obj = json.decode(stringRes);
			if obj.success == false then
				printf("Think we got rate limited, %s", stringRes);
				errors = errors + 1;
				if errors == 8 then
					print("Prolly not a rate limit issue at this point, exiting the program");
					exit(1);
				end
				local waitTime = errors * 10;
				printf("Waiting %d seconds", waitTime);
				os.executef("sleep %d", waitTime);
			else
				errors = 0;
				break
			end
		end

		queryObjs[#queryObjs+1] = obj;
		if page == getTotalPageNum(obj) or getTotalPageNum(obj) <= 0 then
			break;
		end
		if page == 400 then
			print("At page 400 here, something wrong??");
		end
	end

	return queryObjs;
end

local function queryUser(userID)
	printf("Querying user %d", userID);
	local userDeats = {};

	local function getStringRes(page)
		return sendQuery(outFilename, string.format(baseUserTournyQuery, userID, 50, page));
	end
	local function getTotalPageNumber(obj)
		return obj.data.user.tournaments.pageInfo.totalPages;
	end
	
	--Get all a users tournys
	local queryObjs = queryErrorLoopBasic(getStringRes, getTotalPageNumber);

	printf("Got all the pages for user %d", userID);

	--Extract user details
	userDeats.id = queryObjs[1].data.user.id;
	userDeats.bio = queryObjs[1].data.user.bio;
	userDeats.birthday = queryObjs[1].data.user.birthday;
	userDeats.discriminator = queryObjs[1].data.user.discriminator;
	userDeats.playerID = queryObjs[1].data.user.player.id;
	userDeats.gamerTag = queryObjs[1].data.user.player.gamerTag;
	userDeats.prefix = queryObjs[1].data.user.player.prefix;
	users[queryObjs[1].data.user.id] = userDeats;
	
	--Extract the tournament details
	for q = 1, #queryObjs do
		for tournyIdx = 1, #queryObjs[q].data.user.tournaments.nodes do
			local tournyDeats = {};
			local node = queryObjs[q].data.user.tournaments.nodes[tournyIdx];
			for i, v in pairs(node) do
				tournyDeats[i] = v;
			end
			tournaments[node.id] = tournyDeats;
			tournyDeats.events = {};
			tournyDeats.sets = {};

			tournyDeats.beenQueried = false;
		end
	end
	userDeats.beenQueried = true;
end

local function queryEvent(id)
	printf("Querying event %d", id);

	local function getStringRes(page)
		return sendQuery(outFilename, string.format(baseEventSetQuery, id, page, 20));
	end
	local function getTotalPageNumber(obj)
		return obj.data.event.sets.pageInfo.totalPages;
	end

	--All queries for this event
	local queryObjs = queryErrorLoopBasic(getStringRes, getTotalPageNumber);
	
	--For every set
	for q = 1, #queryObjs do
		local obj = queryObjs[q];
		local tournyID = obj.data.event.tournament.id;
		for i, v in pairs(obj.data.event.sets.nodes) do
			if v.completedAt and #v.slots[1].entrant.participants == 1 then
				sets[v.id] = v;
				tournaments[tournyID].sets[#tournaments[tournyID].sets+1] = v.id;

				--Add sets to users, and make new unpopulated users if need be
				for i2, v2 in pairs(v.slots) do
					if v2.entrant.participants[1].user then
						uid = v2.entrant.participants[1].user.id
						if not users[uid] then
							users[uid] = {}
							users[uid].id = uid;
							users[uid].gamerTag = v2.entrant.participants[1].gamerTag;
							users[uid].sets = {v.id};
						else
							users[uid].sets[#users[uid].sets+1] = v.id;
						end
					end
				end
			end
		end
	end
end

local function queryTourny(id)
	printf("Querying tourny %d", id);
	
	local obj = json.decode(sendQuery(outFilename, string.format(baseTournyEventQuery, id)));
	local events = obj.data.tournament.events;

	for i, v in pairs(events) do
		tournaments[id].events[#tournaments[id].events+1] = v.id;
		queryEvent(v.id);
	end

	tournaments[id].beenQueried = true;
end


--Load our db
sets = json.decode(fileRead("data/sets.json"));
tournaments = json.decode(fileRead("data/tournaments.json"));
users = json.decode(fileRead("data/users.json"));


--Thinking about adding an argparse lib to handle this
if false then
	for i, v in pairs(users) do
		if not v.beenQueried then
			queryUser(v.id);
		end
	end

	for i,v in pairs(tournaments) do
		if not v.beenQueried then
			queryTourny(v.id);
		end
	end

	--Save our generated db
	local function writeJsonFile(name,object)
		local file = io.open(name, "w");
		local object2 = {};
		for i, v in pairs(object) do
			object2[tostring(i)] = v;
		end
		file:write(json.encode(object2));
		file:close();
	end

	writeJsonFile("data/sets.json", sets);
	writeJsonFile("data/users.json", users);
	writeJsonFile("data/tournaments.json", tournaments);
end
