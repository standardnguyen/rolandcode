import { TextAttributes } from "@opentui/core"
import { For } from "solid-js"
import { logo } from "@/cli/logo"

export function Logo() {
  return (
    <box>
      <For each={logo}>
        {(line) => (
          <box flexDirection="row">
            <text fg="white" attributes={TextAttributes.BOLD} selectable={false}>
              {line}
            </text>
          </box>
        )}
      </For>
    </box>
  )
}
