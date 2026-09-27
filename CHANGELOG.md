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
- Comments follow their code when the agent edits again. Each one keeps the
  file as it was, and is carried through a diff against the file as it is, so
  a lookalike block elsewhere cannot steal it. Lines rewritten under a comment
  leave it in place and mark it `(code changed since)`. Code moved elsewhere
  is found by its text. Code that is gone marks the comment stale, and it is
  still sent. Whitespace-only changes are ignored, so a formatter run does not
  disturb anything.
- Nothing is sent while the agent's terminal is still printing.
- git is the source of truth, with `:Volley snapshot` for folders without it.
- telescope and snacks are used when installed, otherwise volley draws its own
  list.
