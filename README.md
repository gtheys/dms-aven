# dms-aven

A [DankMaterialShell](https://danklinux.com/docs/dankmaterialshell/plugin-development) **launcher plugin** for the [aven](https://aventasks.dev) todo manager.

Type `av <task title>` in DankLauncher and pick the project the task goes to. If no project fits, create one on the fly — without ever leaving the launcher.

## Features

- **Project picker as you type** — every aven project shows up as a selectable result
- **Direct targeting** — `av fix login @work` narrows to matching projects (matches on key, name, or ref prefix)
- **Create projects inline** — `av fix login @newthing` with no match offers *"Create project 'newthing' and add task"*
- **Inbox escape hatch** — always an option to add without a project (aven's default `inbox` status)
- **Toasts for feedback** — success shows the created task ref (e.g. `TP-4V43`), failures show stderr
- **Configurable** — aven binary path, launcher trigger, default workspace, and both optional items

## Requirements

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (plugin-capable, DMS ≥ 1.2 recommended)
- [aven](https://aventasks.dev/getting-started/) CLI on `PATH` (tested against aven 0.1.x)

```bash
curl -fsSL https://raw.githubusercontent.com/raine/aven/main/scripts/install | bash
# or
brew install raine/aven/aven
```

The plugin declares `"dependencies": ["aven"]` and refuses to load with a helpful message if the CLI is missing.

## Install

```bash
git clone https://github.com/gtheys/dms-aven.git
mkdir -p ~/.config/DankMaterialShell/plugins
ln -s "$(pwd)/dms-aven" ~/.config/DankMaterialShell/plugins/Aven
dms restart   # or: DMS Settings → Plugins → Scan for Plugins
```

Then open **DMS Settings → Plugins**, toggle **Aven Tasks** on, and make sure the trigger (default `av`) is active in DankLauncher.

## Usage

| You type | What happens |
|---|---|
| `av buy milk` | Lists every aven project + "Add to Inbox" — Enter adds to the highlighted one |
| `av buy milk @home` | If exactly one project matches `home`: one-click direct add |
| `av buy milk @hom` | Ambiguous matches are all listed as add-options |
| `av buy milk @gardening` | No match? Offers to **create the project**, then adds the task to it |
| `av` (no title) | Hint results: syntax reminder + your current project list |

Results are tagged with the category `Aven` so you can filter them fast.

## Settings

| Setting | Default | Purpose |
|---|---|---|
| `avenBin` | `aven` | Binary name or full path |
| `trigger` | `av` | Launcher trigger prefix |
| `defaultWorkspace` | *(empty)* | Passed as `--workspace` to every aven call |
| `showInboxOption` | `true` | Show "Add to Inbox (no project)" |
| `showCreateOption` | `true` | Show "Create project … and add task" |

## How it works

The plugin is a thin, lazy wrapper over the verified aven CLI surface:

```
aven project list --json        # cache projects (refreshed on every query)
aven add "Title" --project key  # add task to a project
aven add "Title"                # add task to inbox
aven project create "Name"      # create a project, then add the task
```

## License

MIT
