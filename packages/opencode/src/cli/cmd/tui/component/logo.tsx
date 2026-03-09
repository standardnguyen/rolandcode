import { TextAttributes } from "@opentui/core"
import { For } from "solid-js"
import { useTheme } from "@tui/context/theme"
import { logo } from "@/cli/logo"

export function Logo() {
  const { theme } = useTheme()

  return (
    <box>
      <For each={logo.top}>
        {(line) => (
          <box flexDirection="row">
            <text fg={theme.textMuted} selectable={false}>
              {line}
            </text>
          </box>
        )}
      </For>
      <For each={logo.bottom}>
        {(line) => (
          <box flexDirection="row">
            <text fg={theme.text} attributes={TextAttributes.BOLD} selectable={false}>
              {line}
            </text>
          </box>
        )}
      </For>
    </box>
  )
}
