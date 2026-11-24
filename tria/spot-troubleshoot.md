**Start with your own tools**: `list_spots` for the state, the pause reason, the certificate's expiry, the last wake and its outcome; `list_spot_tasks`; `read_workspace_room` with `room: bus` for the last exchange; `control_spot_task` with `op: wake` to try a wake by hand.

Read the state before anything else:
- `suspended`: healthy, it wakes on a request.
- `paused` with a reason (a daily or hourly ceiling, the workspace cap): it is out of budget until the time shown; `set_spot_limits` or the policy raises it if the person wants.
- `down` minutes after `create_spot`: not joined yet, look again.
- `down` with a certificate past its expiry: it must join again; for a spot you made, `remove_spot` and `create_spot`.
- "it cannot see the cluster": the spot is a Gemini sandbox or has no cluster connector. Make one from a blueprint (see spot-install).

**Hand to another spot that sees that cluster** (`ask_spot`): the failing spot's pod state, events and logs.

**The person does the rest**: Secrets, the enrollment key, network policy and the substrate platform's own tooling. Quote the exact step from the text.
