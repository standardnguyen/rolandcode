import { test, expect } from "bun:test"
import { ShareNext } from "../../src/share/share-next"
import { SessionID } from "../../src/session/schema"

test("ShareNext.url returns empty string (sharing disabled)", async () => {
  expect(await ShareNext.url()).toBe("")
})

test("ShareNext.create returns empty stub", async () => {
  const result = await ShareNext.create(SessionID.make("test-session-id"))
  expect(result).toEqual({ id: "", url: "", secret: "" })
})

test("ShareNext.init is a no-op", async () => {
  // Should not throw
  await ShareNext.init()
})
