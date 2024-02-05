# startggStats
Stats collector just for what I want it for, does a breadth first search starting from a single user, then to every tournament they entered and every set in those tournaments. The users in these sets are then added for the next pass, although I've yet to perform 2 passes because I assume it would take an absurd amount of time.

Thinking about adding some argparse and some more utilities to it at some point.

# Running
You'll need to plug your api key and user id into the thing to kick the process off, I put mine in secret.lua, user id likely doesn't need to be secret but it was convenient for me to put it in there.

# JSON Schema
Objects are stored on disk in the following hierarchy:
```
data/
  users/
    18374837.json (uid.json)
    29819289.json
  tournaments/
    54362892.json (id.json)
```
### User objects
```
id
bio
birthday
discriminator
playerID (from user.player in startgg)
gamerTag (also from user.player)
prefix
tournamentIDs ([] array of tourny IDs)
sets ([] array of set IDs requires build set connections to be ran)
```
### Tournament objects
```
id
name
updatedAt
city
countryCode
lat
lng
mapsPlaceId
numAttendees
startAt
venueAddress
venueName
url
eventIDs ([] array of event ids, not particularily useful tbh)
sets ([] array of {} set objects)
```
### Set objects
```
id
round
completedAt
fullRoundText
displayScore
winnerId (pretty sure this doesn't point to a user, probably a player or entrant)
identifier
lPlacement
setGamesType
state
totalGames
slots ([] array of {} slot objects)
  seedNum (from seed.seedNum)
  scoreValue (from standing.stats.score.value)
  scoreLabel (from standing.stats.score.label)
  scoreDisplayValue (from standing.stats.score.displayValue)
  entrant ({} entrant object)
    id
    initialSeedNum (maybe different? who knows)
    name
    participant ({} participant object) note that in doubles, there would be 2 participants. I refuse to deal with that, so only one :)
      gamerTag
      id
      userName (from user.name) (won't be there if the playe didn't register with a startgg account)
      userID (from user.id) (same for userName, won't be there if the player doesn't have an account)
```
