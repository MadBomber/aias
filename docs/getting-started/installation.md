# Installation

## Requirements

| Requirement | Notes |
|---|---|
| Ruby | >= 3.2.0 |
| `aia` gem | Must be installed and reachable via `which aia` in your login shell |
| `AIA_PROMPTS_DIR` | Environment variable pointing to your AIA prompts directory |

## Install the Gem

```bash
gem install aias
```

Or add it to your project's `Gemfile`:

```ruby
gem "aias"
```

Then run:

```bash
bundle install
```

## Verify Prerequisites

`aias update` will validate that `aia` is reachable and that `AIA_PROMPTS_DIR` is set. You can check manually first:

```bash
# Confirm aia is in your login shell PATH
bash -l -c "which aia"

# Confirm AIA_PROMPTS_DIR is set and points to a real directory
echo $AIA_PROMPTS_DIR
ls "$AIA_PROMPTS_DIR"
```

If `aia` is not found, install it:

```bash
gem install aia
```

## Set AIA_PROMPTS_DIR

Add to your shell profile (`.bashrc`, `.zshrc`, etc.):

```bash
export AIA_PROMPTS_DIR="$HOME/.prompts"
```

Reload your shell or source the file:

```bash
source ~/.zshrc   # or ~/.bashrc
```

## Verify the Installation

```bash
aias --version
aias help
```

`aias help` lists all available commands with descriptions.
