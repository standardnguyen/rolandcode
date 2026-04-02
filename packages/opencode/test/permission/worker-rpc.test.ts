/**
 * Integration test: Full Worker → RPC → Thread permission event chain.
 *
 * Spawns the actual worker process, triggers a permission ask INSIDE it
 * via a test RPC method, and verifies the event arrives back via RPC.
 */
import { test, expect, describe } from "bun:test"
import { Rpc } from "../../src/util/rpc"
import { tmpdir } from "../fixture/fixture"
import type { Event } from "@opencode-ai/sdk/v2"

describe("permission worker RPC", () => {
  test("permission.asked event flows Worker → SSE → RPC → Thread", async () => {
    await using tmp = await tmpdir({ git: true })

    await Bun.write(
      `${tmp.path}/opencode.json`,
      JSON.stringify({ $schema: "https://opencode.ai/config.json", permission: { "*": "ask" } }),
    )

    const workerUrl = new URL("../../src/cli/cmd/tui/worker.ts", import.meta.url)
    const worker = new Worker(workerUrl, {
      env: Object.fromEntries(
        Object.entries(process.env).filter((entry): entry is [string, string] => entry[1] !== undefined),
      ),
    } as any)

    const client = Rpc.client<any>(worker)
    const events: any[] = []
    client.on<Event>("event", (event) => {
      events.push(event)
    })

    // Wait for worker + SSE stream to initialize
    await Bun.sleep(3000)

    // Trigger a permission ask INSIDE the worker process
    console.error("Triggering permission ask inside worker...")
    const result = await client.call("__testPermissionAsk", {
      sessionID: "session_worker_test",
    })
    console.error(`Worker returned: ${JSON.stringify(result)}`)

    // Wait for events to propagate
    await Bun.sleep(1000)

    // Analyze what came through RPC
    const permAsked = events.filter((e) => e.type === "permission.asked")
    const permReplied = events.filter((e) => e.type === "permission.replied")

    console.error("\n=== WORKER→RPC PERMISSION TEST ===")
    console.error(`Total RPC events: ${events.length}`)
    console.error(`Event types: ${events.map((e) => e.type).join(", ")}`)
    console.error(`permission.asked: ${permAsked.length} (expected: 1)`)
    console.error(`permission.replied: ${permReplied.length} (expected: 1)`)
    if (permAsked.length > 0) {
      const p = permAsked[0].properties
      console.error(`  permission=${p?.permission} sessionID=${p?.sessionID} patterns=${JSON.stringify(p?.patterns)}`)
    }
    console.error("===================================\n")

    expect(permAsked.length).toBe(1)
    expect(permAsked[0].properties.permission).toBe("bash")
    expect(permAsked[0].properties.sessionID).toBe("session_worker_test")
    expect(permReplied.length).toBe(1)

    await client.call("shutdown", undefined).catch(() => {})
    worker.terminate()
  }, 15000)
})
