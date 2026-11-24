**You do these yourself**: a spot's own daily token cap with `set_spot_limits`; the workspace's number of spots with `update_workspace`; the policy's spot settings (shared caps, wake and request timings) with `get_policy` and `set_policy` when the person is the core's administrator.

**Not changeable from here**: a spot's model, connectors, tool allowlist, prompt and wake schedule. For a spot you made from a blueprint they are the blueprint's and the same for every spot made from it: an operator changes the blueprint, then the spot is removed and made again (`remove_spot`, `create_spot`). For a spot installed with Helm the person changes its values file and upgrades, always with the full values. Give them the setting's name from the text.

Say plainly which of the two the spot is: `list_spots` shows its runtime.
