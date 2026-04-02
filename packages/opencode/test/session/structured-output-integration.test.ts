import { afterAll, beforeAll, beforeEach, describe, expect, test } from "bun:test"
import path from "path"
import { Session } from "../../src/session"
import { SessionPrompt } from "../../src/session/prompt"
import { Log } from "../../src/util/log"
import { Instance } from "../../src/project/instance"
import { MessageV2 } from "../../src/session/message-v2"
import { tmpdir } from "../fixture/fixture"

Log.init({ print: false })

// Mock Anthropic SSE server
const state = {
  server: null as ReturnType<typeof Bun.serve> | null,
  nextResponse: null as (() => Response) | null,
}

function sseResponse(chunks: unknown[]) {
  const payload = chunks.map((c) => `data: ${JSON.stringify(c)}`).join("\n\n") + "\n\n"
  const encoder = new TextEncoder()
  return new Response(
    new ReadableStream({
      start(controller) {
        controller.enqueue(encoder.encode(payload))
        controller.close()
      },
    }),
    { status: 200, headers: { "Content-Type": "text/event-stream" } },
  )
}

function anthropicTextSSE(text: string) {
  return sseResponse([
    {
      type: "message_start",
      message: {
        id: "msg-structured-1",
        model: "claude-3-5-sonnet-20241022",
        usage: { input_tokens: 10, cache_creation_input_tokens: null, cache_read_input_tokens: null },
      },
    },
    { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
    { type: "content_block_delta", index: 0, delta: { type: "text_delta", text } },
    { type: "content_block_stop", index: 0 },
    {
      type: "message_delta",
      delta: { stop_reason: "end_turn", stop_sequence: null, container: null },
      usage: { input_tokens: 10, output_tokens: 20, cache_creation_input_tokens: null, cache_read_input_tokens: null },
    },
    { type: "message_stop" },
  ])
}

// Simulate the LLM calling the StructuredOutput tool with JSON input
function anthropicToolCallSSE(toolInput: object) {
  const inputJson = JSON.stringify(toolInput)
  return sseResponse([
    {
      type: "message_start",
      message: {
        id: "msg-structured-tool-1",
        model: "claude-3-5-sonnet-20241022",
        usage: { input_tokens: 10, cache_creation_input_tokens: null, cache_read_input_tokens: null },
      },
    },
    {
      type: "content_block_start",
      index: 0,
      content_block: { type: "tool_use", id: "toolu_01", name: "StructuredOutput", input: {} },
    },
    { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: inputJson } },
    { type: "content_block_stop", index: 0 },
    {
      type: "message_delta",
      delta: { stop_reason: "tool_use", stop_sequence: null, container: null },
      usage: { input_tokens: 10, output_tokens: 30, cache_creation_input_tokens: null, cache_read_input_tokens: null },
    },
    { type: "message_stop" },
  ])
}

beforeAll(() => {
  state.server = Bun.serve({
    port: 0,
    async fetch(req) {
      const respond = state.nextResponse ?? (() => anthropicTextSSE("Hello"))
      state.nextResponse = null
      return respond()
    },
  })
})

beforeEach(() => {
  state.nextResponse = null
})

afterAll(() => {
  state.server?.stop()
})

describe("StructuredOutput Integration", () => {
  test(
    "produces structured output with simple schema",
    async () => {
      const server = state.server!
      state.nextResponse = () => anthropicToolCallSSE({ answer: 4, explanation: "2 + 2 equals 4" })

      await using tmp = await tmpdir({
        git: true,
        config: {
          enabled_providers: ["anthropic"],
          provider: {
            anthropic: {
              options: {
                apiKey: "test-key",
                baseURL: `${server.url.origin}/v1`,
              },
            },
          },
        },
      })

      await Instance.provide({
        directory: tmp.path,
        fn: async () => {
          const session = await Session.create({ title: "Structured Output Test" })

          const result = await SessionPrompt.prompt({
            sessionID: session.id,
            parts: [{ type: "text", text: "What is 2 + 2? Provide a simple answer." }],
            format: {
              type: "json_schema",
              schema: {
                type: "object",
                properties: {
                  answer: { type: "number", description: "The numerical answer" },
                  explanation: { type: "string", description: "Brief explanation" },
                },
                required: ["answer"],
              },
              retryCount: 0,
            },
          })

          expect(result.info.role).toBe("assistant")
          if (result.info.role === "assistant") {
            expect(result.info.structured).toBeDefined()
            expect(typeof result.info.structured).toBe("object")

            const output = result.info.structured as any
            expect(output.answer).toBe(4)
            expect(result.info.error).toBeUndefined()
          }
        },
      })
    },
    30000,
  )

  test(
    "produces structured output with nested objects",
    async () => {
      const server = state.server!
      state.nextResponse = () => anthropicToolCallSSE({
        company: { name: "Anthropic", founded: 2021 },
        products: ["Claude"],
      })

      await using tmp = await tmpdir({
        git: true,
        config: {
          enabled_providers: ["anthropic"],
          provider: {
            anthropic: {
              options: {
                apiKey: "test-key",
                baseURL: `${server.url.origin}/v1`,
              },
            },
          },
        },
      })

      await Instance.provide({
        directory: tmp.path,
        fn: async () => {
          const session = await Session.create({ title: "Nested Schema Test" })

          const result = await SessionPrompt.prompt({
            sessionID: session.id,
            parts: [{ type: "text", text: "Tell me about Anthropic company in a structured format." }],
            format: {
              type: "json_schema",
              schema: {
                type: "object",
                properties: {
                  company: {
                    type: "object",
                    properties: {
                      name: { type: "string" },
                      founded: { type: "number" },
                    },
                    required: ["name", "founded"],
                  },
                  products: {
                    type: "array",
                    items: { type: "string" },
                  },
                },
                required: ["company"],
              },
              retryCount: 0,
            },
          })

          expect(result.info.role).toBe("assistant")
          if (result.info.role === "assistant") {
            expect(result.info.structured).toBeDefined()
            const output = result.info.structured as any

            expect(output.company).toBeDefined()
            expect(output.company.name).toBe("Anthropic")
            expect(typeof output.company.founded).toBe("number")

            if (output.products) {
              expect(Array.isArray(output.products)).toBe(true)
            }
            expect(result.info.error).toBeUndefined()
          }
        },
      })
    },
    30000,
  )

  test(
    "works with text outputFormat (default)",
    async () => {
      const server = state.server!
      state.nextResponse = () => anthropicTextSSE("Hello! How can I help you today?")

      await using tmp = await tmpdir({
        git: true,
        config: {
          enabled_providers: ["anthropic"],
          provider: {
            anthropic: {
              options: {
                apiKey: "test-key",
                baseURL: `${server.url.origin}/v1`,
              },
            },
          },
        },
      })

      await Instance.provide({
        directory: tmp.path,
        fn: async () => {
          const session = await Session.create({ title: "Text Output Test" })

          const result = await SessionPrompt.prompt({
            sessionID: session.id,
            parts: [{ type: "text", text: "Say hello." }],
            format: { type: "text" },
          })

          expect(result.info.role).toBe("assistant")
          if (result.info.role === "assistant") {
            expect(result.info.structured).toBeUndefined()
            expect(result.info.error).toBeUndefined()
          }
          expect(result.parts.length).toBeGreaterThan(0)
        },
      })
    },
    30000,
  )

  test(
    "stores outputFormat on user message",
    async () => {
      const server = state.server!
      state.nextResponse = () => anthropicToolCallSSE({ result: 2 })

      await using tmp = await tmpdir({
        git: true,
        config: {
          enabled_providers: ["anthropic"],
          provider: {
            anthropic: {
              options: {
                apiKey: "test-key",
                baseURL: `${server.url.origin}/v1`,
              },
            },
          },
        },
      })

      await Instance.provide({
        directory: tmp.path,
        fn: async () => {
          const session = await Session.create({ title: "OutputFormat Storage Test" })

          await SessionPrompt.prompt({
            sessionID: session.id,
            parts: [{ type: "text", text: "What is 1 + 1?" }],
            format: {
              type: "json_schema",
              schema: {
                type: "object",
                properties: {
                  result: { type: "number" },
                },
                required: ["result"],
              },
              retryCount: 3,
            },
          })

          const messages = await Session.messages({ sessionID: session.id })
          const userMessage = messages.find((m) => m.info.role === "user")

          expect(userMessage).toBeDefined()
          if (userMessage?.info.role === "user") {
            expect(userMessage.info.format).toBeDefined()
            expect(userMessage.info.format?.type).toBe("json_schema")
            if (userMessage.info.format?.type === "json_schema") {
              expect(userMessage.info.format.retryCount).toBe(3)
            }
          }
        },
      })
    },
    30000,
  )

  test("unit test: StructuredOutputError is properly structured", () => {
    const error = new MessageV2.StructuredOutputError({
      message: "Failed to produce valid structured output after 3 attempts",
      retries: 3,
    })

    expect(error.name).toBe("StructuredOutputError")
    expect(error.data.message).toContain("3 attempts")
    expect(error.data.retries).toBe(3)

    const obj = error.toObject()
    expect(obj.name).toBe("StructuredOutputError")
    expect(obj.data.retries).toBe(3)
  })
})
