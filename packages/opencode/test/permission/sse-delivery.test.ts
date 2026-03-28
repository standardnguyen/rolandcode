/**
 * Integration test: Permission event delivery via SSE
 *
 * Tests the full chain that the TUI relies on:
 *   PermissionNext.ask() → Bus.publish → /event SSE endpoint → SDK client
 *
 * If this test passes, the break is in the TUI rendering layer.
 * If this test fails, the break is in the server/SSE/Bus layer.
 */
import { test, expect, describe } from "bun:test"
import { Bus } from "../../src/bus"
import { PermissionNext } from "../../src/permission/next"
import { PermissionID } from "../../src/permission/schema"
import { Instance } from "../../src/project/instance"
import { Server } from "../../src/server/server"
import { SessionID, MessageID } from "../../src/session/schema"
import { tmpdir } from "../fixture/fixture"

/** Helper: read SSE events from the /event endpoint via in-process fetch */
async function collectSSEEvents(
  app: ReturnType<typeof Server.Default>,
  signal: AbortSignal,
  directory: string,
  maxEvents = 10,
): Promise<Array<{ type: string; properties?: any }>> {
  const events: Array<{ type: string; properties?: any }> = []

  const response = await app.fetch(
    new Request(`http://localhost/event?directory=${encodeURIComponent(directory)}`, {
      headers: { Accept: "text/event-stream" },
      signal,
    }),
  )

  if (!response.body) throw new Error("No response body from /event")

  const reader = response.body.pipeThrough(new TextDecoderStream()).getReader()
  let buffer = ""

  while (events.length < maxEvents) {
    const { done, value } = await reader.read()
    if (done) break
    buffer += value

    // Parse SSE chunks (separated by double newline)
    const chunks = buffer.split("\n\n")
    buffer = chunks.pop() ?? ""

    for (const chunk of chunks) {
      for (const line of chunk.split("\n")) {
        if (line.startsWith("data:")) {
          const raw = line.slice(5).trim()
          if (!raw) continue
          try {
            const parsed = JSON.parse(raw)
            events.push(parsed)
          } catch {
            // skip non-JSON data lines
          }
        }
      }
    }
  }

  return events
}

describe("permission SSE delivery", () => {
  test("Bus.publish(Event.Asked) is received by local Bus.subscribeAll", async () => {
    await using tmp = await tmpdir({ git: true })
    await Instance.provide({
      directory: tmp.path,
      fn: async () => {
        const received: any[] = []
        const unsub = Bus.subscribeAll((event) => {
          if (event.type === "permission.asked") {
            received.push(event)
          }
        })

        // Trigger ask with an empty ruleset (defaults to "ask")
        const askPromise = PermissionNext.ask({
          id: PermissionID.make("per_sse_test1"),
          sessionID: SessionID.make("session_sse_test"),
          permission: "bash",
          patterns: ["ls"],
          metadata: {},
          always: ["ls"],
          ruleset: [], // empty = defaults to "ask"
        })

        // Give the async publish a tick to complete
        await Bun.sleep(50)

        expect(received.length).toBe(1)
        expect(received[0].properties.permission).toBe("bash")
        expect(received[0].properties.patterns).toEqual(["ls"])
        expect(received[0].properties.sessionID).toBe("session_sse_test")

        unsub()

        // Clean up: reject to unblock the ask
        await PermissionNext.reply({
          requestID: PermissionID.make("per_sse_test1"),
          reply: "reject",
        })
        await askPromise.catch(() => {})
      },
    })
  })

  test("Bus.publish(Event.Asked) reaches /event SSE endpoint", async () => {
    await using tmp = await tmpdir({ git: true })
    await Instance.provide({
      directory: tmp.path,
      fn: async () => {
        const app = Server.Default()
        const abort = new AbortController()

        // Start collecting SSE events (runs in background)
        const eventsPromise = collectSSEEvents(app, abort.signal, tmp.path, 5)

        // Wait a moment for SSE connection to establish
        await Bun.sleep(100)

        // Trigger a permission ask
        const askPromise = PermissionNext.ask({
          id: PermissionID.make("per_sse_test2"),
          sessionID: SessionID.make("session_sse_test2"),
          permission: "bash",
          patterns: ["ls -la"],
          metadata: { cmd: "ls -la" },
          always: ["ls *"],
          ruleset: [], // empty = defaults to "ask"
        })

        // Wait for the event to propagate
        await Bun.sleep(200)

        // Reply via HTTP (the way the TUI does it)
        const replyResponse = await app.fetch(
          new Request(`http://localhost/permission/per_sse_test2/reply?directory=${encodeURIComponent(tmp.path)}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ reply: "once" }),
          }),
        )
        expect(replyResponse.status).toBe(200)

        // The ask should resolve (no error = permission granted)
        await askPromise

        // Wait a bit more for reply event
        await Bun.sleep(100)

        // Stop SSE collection
        abort.abort()

        const events = await eventsPromise.catch(() => [] as any[])

        // Filter to permission events only
        const permEvents = events.filter(
          (e) => e.type === "permission.asked" || e.type === "permission.replied",
        )

        console.error("\n=== SSE DELIVERY TEST RESULTS ===")
        console.error(`Total SSE events received: ${events.length}`)
        console.error(`Event types: ${events.map((e) => e.type).join(", ")}`)
        console.error(`Permission events: ${permEvents.length}`)
        for (const e of permEvents) {
          console.error(`  ${e.type}: ${JSON.stringify(e.properties)}`)
        }
        console.error("=================================\n")

        // The critical assertion: did the permission.asked event reach SSE?
        const asked = permEvents.find((e) => e.type === "permission.asked")
        expect(asked).toBeDefined()
        expect(asked!.properties.permission).toBe("bash")
        expect(asked!.properties.patterns).toEqual(["ls -la"])

        // Did the reply event also arrive?
        const replied = permEvents.find((e) => e.type === "permission.replied")
        expect(replied).toBeDefined()
      },
    })
  })

  test("permission list HTTP endpoint shows pending requests", async () => {
    await using tmp = await tmpdir({ git: true })
    await Instance.provide({
      directory: tmp.path,
      fn: async () => {
        const app = Server.Default()

        // Trigger a permission ask
        const askPromise = PermissionNext.ask({
          id: PermissionID.make("per_sse_test3"),
          sessionID: SessionID.make("session_sse_test3"),
          permission: "bash",
          patterns: ["rm -rf /"],
          metadata: {},
          always: [],
          ruleset: [],
        })

        await Bun.sleep(50)

        // Check the list endpoint
        const listResponse = await app.fetch(
          new Request(`http://localhost/permission?directory=${encodeURIComponent(tmp.path)}`, {
            method: "GET",
          }),
        )
        expect(listResponse.status).toBe(200)
        const pending = await listResponse.json()
        expect(pending.length).toBe(1)
        expect(pending[0].permission).toBe("bash")
        expect(pending[0].id).toBe("per_sse_test3")

        // Clean up
        await PermissionNext.reply({
          requestID: PermissionID.make("per_sse_test3"),
          reply: "reject",
        })
        await askPromise.catch(() => {})
      },
    })
  })

  test("rolandcode-style ruleset: defaults + user ask produces correct evaluation", async () => {
    // Reproduce the exact ruleset that rolandcode builds for the "build" agent
    const defaults = PermissionNext.fromConfig({
      "*": "allow",
      doom_loop: "ask",
      question: "deny",
      plan_enter: "deny",
      plan_exit: "deny",
      read: {
        "*": "allow",
        "*.env": "ask",
        "*.env.*": "ask",
        "*.env.example": "allow",
      },
    })

    const buildSpecific = PermissionNext.fromConfig({
      question: "allow",
      plan_enter: "allow",
    })

    const userConfig = PermissionNext.fromConfig({
      "*": "ask",
      read: {
        "*": "allow",
        "*.env": "ask",
        "*.env.*": "ask",
        "*.env.example": "allow",
      },
    })

    const merged = PermissionNext.merge(defaults, buildSpecific, userConfig)

    // Bash with "ls" pattern — user's "*":"ask" should be the last match
    const bashLs = PermissionNext.evaluate("bash", "ls", merged)
    console.error(`\n=== RULESET EVALUATION ===`)
    console.error(`bash "ls": action=${bashLs.action} (expected: ask)`)
    expect(bashLs.action).toBe("ask")

    // Bash with "ls -la /shares_of_shares/avalanche-audit/" — same
    const bashLsLa = PermissionNext.evaluate(
      "bash",
      "ls -la /shares_of_shares/avalanche-audit/",
      merged,
    )
    console.error(
      `bash "ls -la /shares_of_shares/avalanche-audit/": action=${bashLsLa.action} (expected: ask)`,
    )
    expect(bashLsLa.action).toBe("ask")

    // Read should be "allow" (user config has read.* = allow)
    const readFile = PermissionNext.evaluate("read", "foo.txt", merged)
    console.error(`read "foo.txt": action=${readFile.action} (expected: allow)`)
    expect(readFile.action).toBe("allow")

    // Read .env should be "ask"
    const readEnv = PermissionNext.evaluate("read", ".env", merged)
    console.error(`read ".env": action=${readEnv.action} (expected: ask)`)
    expect(readEnv.action).toBe("ask")

    console.error(`===========================\n`)
  })

  test("full ask→SSE→reply pipeline with rolandcode ruleset", async () => {
    await using tmp = await tmpdir({ git: true })
    await Instance.provide({
      directory: tmp.path,
      fn: async () => {
        const app = Server.Default()

        // Build the exact ruleset rolandcode uses
        const defaults = PermissionNext.fromConfig({
          "*": "allow",
          doom_loop: "ask",
          question: "deny",
          plan_enter: "deny",
          plan_exit: "deny",
          read: {
            "*": "allow",
            "*.env": "ask",
            "*.env.*": "ask",
            "*.env.example": "allow",
          },
        })
        const buildSpecific = PermissionNext.fromConfig({
          question: "allow",
          plan_enter: "allow",
        })
        const userConfig = PermissionNext.fromConfig({
          "*": "ask",
          read: {
            "*": "allow",
            "*.env": "ask",
            "*.env.*": "ask",
            "*.env.example": "allow",
          },
        })
        const ruleset = PermissionNext.merge(defaults, buildSpecific, userConfig)

        // Subscribe to Bus events directly to verify publish
        let busEventSeen = false
        const unsub = Bus.subscribe(PermissionNext.Event.Asked, () => {
          busEventSeen = true
        })

        // Start SSE listener
        const abort = new AbortController()
        const sseEvents: any[] = []
        const ssePromise = (async () => {
          const response = await app.fetch(
            new Request(`http://localhost/event?directory=${encodeURIComponent(tmp.path)}`, {
              headers: { Accept: "text/event-stream" },
              signal: abort.signal,
            }),
          )
          if (!response.body) return
          const reader = response.body.pipeThrough(new TextDecoderStream()).getReader()
          let buffer = ""
          try {
            while (true) {
              const { done, value } = await reader.read()
              if (done) break
              buffer += value
              const chunks = buffer.split("\n\n")
              buffer = chunks.pop() ?? ""
              for (const chunk of chunks) {
                for (const line of chunk.split("\n")) {
                  if (line.startsWith("data:")) {
                    try {
                      sseEvents.push(JSON.parse(line.slice(5).trim()))
                    } catch {}
                  }
                }
              }
            }
          } catch {}
        })()

        await Bun.sleep(100)

        // Trigger ask with the rolandcode ruleset
        const askPromise = PermissionNext.ask({
          id: PermissionID.make("per_full_test"),
          sessionID: SessionID.make("session_full_test"),
          permission: "bash",
          patterns: ["ls -la /shares_of_shares/avalanche-audit/"],
          metadata: { cmd: "ls -la /shares_of_shares/avalanche-audit/" },
          always: ["ls *"],
          tool: {
            messageID: MessageID.make("msg_full_test"),
            callID: "call_full_test",
          },
          ruleset,
        })

        await Bun.sleep(200)

        // Check each link in the chain
        console.error("\n=== FULL PIPELINE TEST ===")

        // 1. Did the permission service accept the ask?
        const pending = await PermissionNext.list()
        console.error(`1. Pending requests: ${pending.length} (expected: 1)`)
        expect(pending.length).toBe(1)

        // 2. Did Bus.subscribe receive the event?
        console.error(`2. Bus event seen: ${busEventSeen} (expected: true)`)
        expect(busEventSeen).toBe(true)

        // 3. Did SSE deliver the event?
        const ssePermAsked = sseEvents.filter((e) => e.type === "permission.asked")
        console.error(`3. SSE permission.asked events: ${ssePermAsked.length} (expected: 1)`)
        if (ssePermAsked.length > 0) {
          console.error(`   sessionID: ${ssePermAsked[0].properties?.sessionID}`)
          console.error(`   permission: ${ssePermAsked[0].properties?.permission}`)
          console.error(`   patterns: ${JSON.stringify(ssePermAsked[0].properties?.patterns)}`)
        }

        // 4. Can we reply via HTTP? (how TUI replies)
        const replyRes = await app.fetch(
          new Request(`http://localhost/permission/per_full_test/reply?directory=${encodeURIComponent(tmp.path)}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ reply: "once" }),
          }),
        )
        console.error(`4. Reply HTTP status: ${replyRes.status} (expected: 200)`)
        expect(replyRes.status).toBe(200)

        // 5. Did ask() resolve? (means permission was granted)
        const askResult = await Promise.race([
          askPromise.then(() => "resolved"),
          Bun.sleep(1000).then(() => "timeout"),
        ])
        console.error(`5. ask() result: ${askResult} (expected: resolved)`)
        expect(askResult).toBe("resolved")

        // 6. Did SSE deliver the reply event?
        await Bun.sleep(100)
        const ssePermReplied = sseEvents.filter((e) => e.type === "permission.replied")
        console.error(`6. SSE permission.replied events: ${ssePermReplied.length} (expected: 1)`)

        console.error(`\nAll SSE events: ${sseEvents.map((e) => e.type).join(", ")}`)
        console.error("==========================\n")

        // Assertions for the critical SSE delivery
        expect(ssePermAsked.length).toBe(1)
        expect(ssePermAsked[0].properties.permission).toBe("bash")

        // Cleanup — abort FIRST to kill the SSE reader, then wait briefly
        abort.abort()
        unsub()
        // Don't await ssePromise — the abort signal breaks the reader
        await Bun.sleep(50)
      },
    })
  })

  test("SDK client receives permission events via SSE (worker path)", async () => {
    // This tests the exact path the worker uses:
    //   Server.Default().fetch → SDK SSE client → events.stream → yield Event
    await using tmp = await tmpdir({ git: true })
    await Instance.provide({
      directory: tmp.path,
      fn: async () => {
        const app = Server.Default()

        const fetchFn = (async (input: RequestInfo | URL, init?: RequestInit) => {
          return app.fetch(new Request(input, init))
        }) as typeof globalThis.fetch

        // This is exactly how worker.ts creates the SDK client
        const { createOpencodeClient } = await import("@opencode-ai/sdk/v2")
        const sdk = createOpencodeClient({
          baseUrl: "http://opencode.internal",
          directory: tmp.path,
          fetch: fetchFn,
        })

        const abort = new AbortController()
        const sdkEvents: any[] = []

        // Start the SDK event stream (mirrors worker.ts startEventStream)
        const streamPromise = (async () => {
          const events = await sdk.event.subscribe({}, { signal: abort.signal })
          for await (const event of events.stream) {
            if (abort.signal.aborted) break
            sdkEvents.push(event)
            // Stop after we get the permission events
            if (sdkEvents.length >= 4) break
          }
        })().catch(() => {})

        await Bun.sleep(100)

        // Trigger a permission ask
        const askPromise = PermissionNext.ask({
          id: PermissionID.make("per_sdk_test"),
          sessionID: SessionID.make("session_sdk_test"),
          permission: "bash",
          patterns: ["ls"],
          metadata: {},
          always: ["ls"],
          ruleset: [],
        })

        await Bun.sleep(200)

        // Reply via HTTP (same way TUI does it)
        await app.fetch(
          new Request(`http://opencode.internal/permission/per_sdk_test/reply?directory=${encodeURIComponent(tmp.path)}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ reply: "once" }),
          }),
        )

        await Promise.race([askPromise, Bun.sleep(1000)])
        await Bun.sleep(100)

        console.error("\n=== SDK CLIENT TEST ===")
        console.error(`SDK events received: ${sdkEvents.length}`)
        for (const e of sdkEvents) {
          console.error(`  type: ${(e as any).type}`)
        }

        const permAsked = sdkEvents.filter((e: any) => e.type === "permission.asked")
        console.error(`permission.asked events: ${permAsked.length}`)

        const permReplied = sdkEvents.filter((e: any) => e.type === "permission.replied")
        console.error(`permission.replied events: ${permReplied.length}`)
        console.error("======================\n")

        expect(permAsked.length).toBe(1)
        expect((permAsked[0] as any).properties.permission).toBe("bash")

        // Cleanup
        abort.abort()
        await streamPromise
      },
    })
  })
})
