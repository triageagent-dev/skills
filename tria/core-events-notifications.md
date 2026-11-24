**You do these yourself**: `list_notify_channels` for a workspace's channels, `delete_notify_channel`, `test_notify` to send a test through a channel and `test_push` for a phone push.

**The person does these**: adding or changing a channel. It needs a webhook URL or a token, which is a secret, so `set_notify_channel` is not offered to you. Tell them to set it in the console's notifications panel; never take a webhook URL in the chat. The same holds for the events server's tokens and for the operator's routing cell, which is applied with kubectl from a checkout of the core.

After they add a channel, offer `test_notify` and read back what it reports.
