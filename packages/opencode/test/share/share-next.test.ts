import { test, expect } from "bun:test"
import { Effect } from "effect"
import { ShareNext } from "../../src/share/share-next"
import { SessionID } from "../../src/session/schema"

const withLayer = <A, E>(effect: Effect.Effect<A, E, ShareNext.Service>) =>
  Effect.runPromise(effect.pipe(Effect.provide(ShareNext.defaultLayer)))

test("ShareNext.url returns empty string (sharing stripped)", async () => {
  const result = await withLayer(ShareNext.Service.use((svc) => svc.url()))
  expect(result).toBe("")
})

test("ShareNext.request returns empty stub", async () => {
  const result = await withLayer(ShareNext.Service.use((svc) => svc.request()))
  expect(result.baseUrl).toBe("")
  expect(result.headers).toEqual({})
})

test("ShareNext.create returns empty stub (sharing stripped)", async () => {
  const result = await withLayer(
    ShareNext.Service.use((svc) => svc.create(SessionID.make("test-session-id"))),
  )
  expect(result).toEqual({ id: "", url: "", secret: "" })
})

test("ShareNext.init is a no-op", async () => {
  await withLayer(ShareNext.Service.use((svc) => svc.init()))
})
