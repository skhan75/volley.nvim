# Changelog

## 0.1.0

First release.

- `<leader>v` opens the files an agent changed, most changed first, with its
  edits beside the list.
- `<leader>va` writes a comment on a line or a selection, shown under the code.
- `<leader>vs` sends every comment to the agent in one message. It goes into
  the window the agent is already running in, so it answers there and asks
  before it edits. With no window to find, volley runs the agent as a command
  and shows the answer in a split.
- Comments follow their code when the agent edits again. A comment whose code
  is gone is marked stale and still sent.
- Nothing is sent while the agent's terminal is still printing.
- git is the source of truth, with `:Volley snapshot` for folders without it.
- telescope and snacks are used when installed, otherwise volley draws its own
  list.
