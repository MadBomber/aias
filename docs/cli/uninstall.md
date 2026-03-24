# aias uninstall

Remove the `aias`-managed environment block from `~/.config/aia/schedule/env.sh`.

```bash
aias uninstall
```

Aliases: `aias unins`

---

## What It Does

Strips the `# BEGIN aias-env` / `# END aias-env` block from `env.sh`. If the file becomes empty after removal it is deleted. Content you have written outside the markers is preserved.

The schedule configuration (`~/.config/aia/schedule/aia.yml`) and installed cron jobs are not touched. To remove the cron jobs themselves use [`aias clear`](clear.md).

## Example Output

```
aias: env vars removed from ~/.config/aia/schedule/env.sh
      ~/.config/aia/schedule/ is unchanged
```

## See Also

- [`aias install`](install.md) — capture or refresh the environment block
- [`aias clear`](clear.md) — remove all aias-managed crontab entries
