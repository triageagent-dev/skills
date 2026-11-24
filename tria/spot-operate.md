**You do these yourself**: `list_spots` (state, runtime, tokens today, last wake, open requests), `get_spot_identity`, `list_spot_tasks`, `control_spot_task` (wake, stop, drop), `set_spot_limits` for a spot's own daily cap, `remove_spot`, and `read_workspace_room` with `room: bus` to read what you and a spot said to each other. `recall_spot_requests` and `list_promises` show what is booked for later.

**Hand to the cluster spot** (`ask_spot`): reading a spot's own pod or its logs, when the workspace has a spot that can see that cluster.

**The person does these**: rotating a spot's key, upgrading the chart or an actor's image, and pausing by changing Helm values. Give the command from the text.

A spot that is `suspended` is healthy and wakes on the next request. Removing a spot revokes its certificate; ask for a clear yes first.
