--Queries a user or tournament by ID


local secret = require("lib.secret");
local json = require("lib.json");
local inspect = require("lib.inspect");
local argparse = require("lib.argparse");
require("lib.common");

local outFilename = "queryout.txt";

local apiKey = secret.apiKey;
local queryLink = "https://api.start.gg/gql/alpha";


--Read in the queries
local baseUserTournyQuery = fileRead("queries/userQuery.txt");
local baseTournyEventQuery = fileRead("queries/tourneyQuery.txt");
local baseEventSetQuery = fileRead("queries/eventQuery.txt");


--Verbose printing functions
local printfv;
local printv;
if true then
	printfv = printf;
	printv = print;
else
	printfv = function() end
	printv = printfv;
end

local function sendQuery(outFilename, query, operationName, variables)
	local queryJson = json.encode({["query"]=query, ["operationName"]=operationName, ["variables"]=variables});
	os.executef(
		[[curl -s -o %s -g -X POST -H "Content-Type: application/json" -H "Authorization: Bearer %s" -d '%s' %s]],
		outFilename, apiKey, queryJson, queryLink
	);
	return fileRead(outFilename);
end

--Does the paged query loop and handles SOME errors
local function queryErrorLoopBasic(wayToGetStringResFunc, getTotalPageNum)
	local queryObjs = {};

	for page = 1, 500 do
		printfv("On page %d\n", page);
		local stringRes, obj;
		local errors = 0;
		while true do
			stringRes = wayToGetStringResFunc(page);
			printv(stringRes);
			--Sometimes the endpoint returns html data because of course it does
			local succ, errorObj = pcall(json.decode, stringRes);
			if not succ then
				obj = {};
				obj.success = false;
				obj.decodeFailed = true;
			else
				obj = errorObj;
			end
			if obj.success == false then
				printf("Think we got rate limited, %s", stringRes);
				if obj.decodeFailed then
					print("Actually json decode failed for some reason, html?");
				end
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


--Returns a user obj
local function queryUser(userID)
	printf("Querying user %d", userID);
	
	local function getStringRes(page)
		return sendQuery(outFilename, string.format(baseUserTournyQuery, userID, 15, page));
	end
	local function getTotalPageNumber(obj)
		return obj.data.user.tournaments.pageInfo.totalPages;
	end
	
	--Get all a users tournys
	local queryObjs = queryErrorLoopBasic(getStringRes, getTotalPageNumber);
	
	printf("Got all the pages for user %d", userID);

	local userDeats = {};

	--Extract user details
	userDeats.id = queryObjs[1].data.user.id;
	userDeats.bio = queryObjs[1].data.user.bio;
	userDeats.birthday = queryObjs[1].data.user.birthday;
	userDeats.discriminator = queryObjs[1].data.user.discriminator;
	userDeats.playerID = queryObjs[1].data.user.player.id;
	userDeats.gamerTag = queryObjs[1].data.user.player.gamerTag;
	userDeats.prefix = queryObjs[1].data.user.player.prefix;
	userDeats.tournamentIDs = {};

	--Extract images (if any)
	userDeats.images = {};
	for q=1, #queryObjs[1].data.user.images do
		local img = queryObjs[1].data.user.images[q];
		userDeats.images[q] = img;
	end
	
	--Extract the tournament details
	for q = 1, #queryObjs do
		for tournyIdx = 1, #queryObjs[q].data.user.tournaments.nodes do
			local node = queryObjs[q].data.user.tournaments.nodes[tournyIdx];
			userDeats.tournamentIDs[#userDeats.tournamentIDs+1] = node.id;
		end
	end
	return userDeats;
end


--Returns a list of sets at an event
local function queryEvent(id)
	printf("Querying event %d", id);

	local function getStringRes(page)
		return sendQuery(outFilename, string.format(baseEventSetQuery, id, page, 10));
	end
	local function getTotalPageNumber(obj)
		return obj.data.event.sets.pageInfo.totalPages;
	end

	--All queries for this event
	local queryObjs = queryErrorLoopBasic(getStringRes, getTotalPageNumber);

	local setsRet = {};
	
	--For every paged query
	for q = 1, #queryObjs do
		local obj = queryObjs[q];
		--For every set
		for i, v in pairs(obj.data.event.sets.nodes) do
			local currSet = {};
			local setIsGood = true;
			
			--Basic data
			currSet.id = v.id;
			currSet.round = v.round;
			currSet.completedAt = v.completedAt;
			currSet.fullRoundText = v.fullRoundText;
			currSet.displayScore = v.displayScore;
			currSet.winnerId = v.winnerId;
			currSet.identifier = v.identifier;
			currSet.lPlacement = v.lPlacement;
			currSet.setGamesType = v.setGamesType;
			currSet.state = v.state;
			currSet.totalGames = v.totalGames;

			--If the set isn't completed
			if not currSet.completedAt then
				setIsGood = false;
			else
				currSet.slots = {};
				--There should really only be 2 slots
				for _, slot in pairs(v.slots) do
					local currSlot = {};
					currSlot.seedNum = slot.seed.seedNum;
					currSlot.scoreValue = slot.standing.stats.score.value;
					currSlot.scoreLabel = slot.standing.stats.score.label;
					currSlot.scoreDisplayValue = slot.standing.stats.score.displayValue;

					currSlot.entrant = {};
					currSlot.entrant.id = slot.entrant.id;
					currSlot.entrant.initialSeedNum = slot.entrant.initialSeedNum
					currSlot.entrant.name = slot.entrant.name;

					if #slot.entrant.participants ~= 1 then
						--Doubles, abort immediately
						setIsGood = false;
						break;
					end
					currSlot.entrant.participant = {};
					currSlot.entrant.participant.gamerTag = slot.entrant.participants[1].gamerTag;
					currSlot.entrant.participant.id = slot.entrant.participants[1].id;
					if slot.entrant.participants[1].user then
						currSlot.entrant.participant.userName = slot.entrant.participants[1].user.name;
						currSlot.entrant.participant.userID = slot.entrant.participants[1].user.id;
					end

					currSet.slots[#currSet.slots+1] = currSlot;
				end
			end

			if setIsGood then
				setsRet[#setsRet+1] = currSet;
			end
		end
	end
	return setsRet;
end

--Returns a full tournament object
local function queryTourny(id)
	printf("Querying tourny %d", id);
	local tournObj = {};
	local stringRes = sendQuery(outFilename, string.format(baseTournyEventQuery, id));
	printv(stringRes);

	local succ, obj = pcall(json.decode, stringRes);
	if not succ or (succ and (obj.success == false)) then
		print("Query tourny json decode failed or something idk, sleeping 10 seconds");
		os.execute("sleep 10");
		return queryTourny(id);
	end


	tournObj.id = obj.data.tournament.id;
	tournObj.name = obj.data.tournament.name;
	tournObj.updatedAt = obj.data.tournament.updatedAt;
	tournObj.city = obj.data.tournament.city;
	tournObj.countryCode = obj.data.tournament.countryCode;
	tournObj.lat = obj.data.tournament.lat;
	tournObj.lng = obj.data.tournament.lng;
	tournObj.mapsPlaceId = obj.data.tournament.mapsPlaceId;
	tournObj.numAttendees = obj.data.tournament.numAttendees;
	tournObj.startAt = obj.data.tournament.startAt;
	tournObj.venueAddress = obj.data.tournament.venueAddress;
	tournObj.venueName = obj.data.tournament.venueName;
	tournObj.url = obj.data.tournament.url;

	--Extract images (if any)
	tournObj.images = {};
	for q=1, #obj.data.tournament.images do
		local img = obj.data.tournament.images[q];
		tournObj.images[q] = img;
	end

	tournObj.eventIDs = {};
	tournObj.sets = {};

	local events = obj.data.tournament.events;

	for i, v in pairs(events) do
		tournObj.eventIDs[#tournObj.eventIDs+1] = v.id;
		local eventRes = queryEvent(v.id);
		for i, v in ipairs(eventRes) do
			tournObj.sets[#tournObj.sets+1] = v;
		end
	end
	return tournObj;
end


local collect = {};

function collect.doUser(id)
	fileWrite("data/users/" .. tostring(id) .. ".json", json.encode(queryUser(id)));
end

function collect.doTourny(id)
	fileWrite("data/tournaments/" .. tostring(id) .. ".json", json.encode(queryTourny(id)));
end


return collect;
