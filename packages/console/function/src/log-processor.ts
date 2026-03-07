import type { TraceItem } from "@cloudflare/workers-types"

export default {
  async tail(_events: TraceItem[]) {
    // Honeycomb telemetry removed — log processor is now a no-op
  },
}
