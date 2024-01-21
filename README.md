# startggStats
Stats collector just for what I want it for, does a breadth first search starting from a single user, then to every tournament they entered and every set in those tournaments. The users in these sets are then added for the next pass, although I've yet to perform 2 passes because I assume it would take an absurd amount of time.

Thinking about adding some argparse and some more utilities to it at some point.

# Running
You'll need to plug your api key and user id into the thing to kick the process off, I put mine in secret.lua, user id likely doesn't need to be secret but it was convenient for me to put it in there.
