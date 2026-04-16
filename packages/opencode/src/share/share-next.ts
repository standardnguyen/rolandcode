import { Effect, Layer, Schema, Context } from "effect"
import { Database, eq } from "@/storage/db"
import type { SessionID } from "@/session/schema"
import { SessionShareTable } from "./share.sql"

// Sharing is stripped. This module provides a no-op implementation that
// satisfies the Effect Service contract but never phones home.
export namespace ShareNext {
  export type Api = {
    create: string
    sync: (shareID: string) => string
    remove: (shareID: string) => string
    data: (shareID: string) => string
  }

  export type Req = {
    headers: Record<string, string>
    api: Api
    baseUrl: string
  }

  const ShareSchema = Schema.Struct({
    id: Schema.String,
    url: Schema.String,
    secret: Schema.String,
  })
  export type Share = typeof ShareSchema.Type

  export interface Interface {
    readonly init: () => Effect.Effect<void, unknown>
    readonly url: () => Effect.Effect<string, unknown>
    readonly request: () => Effect.Effect<Req, unknown>
    readonly create: (sessionID: SessionID) => Effect.Effect<Share, unknown>
    readonly remove: (sessionID: SessionID) => Effect.Effect<void, unknown>
  }

  export class Service extends Context.Service<Service, Interface>()("@opencode/ShareNext") {}

  function api(resource: string): Api {
    return {
      create: `/api/${resource}`,
      sync: (shareID) => `/api/${resource}/${shareID}/sync`,
      remove: (shareID) => `/api/${resource}/${shareID}`,
      data: (shareID) => `/api/${resource}/${shareID}/data`,
    }
  }

  const stubApi = api("share")

  export const layer = Layer.succeed(
    Service,
    Service.of({
      init: () => Effect.void,
      url: () => Effect.succeed(""),
      request: () =>
        Effect.succeed<Req>({
          headers: {},
          api: stubApi,
          baseUrl: "",
        }),
      create: (_sessionID: SessionID) =>
        Effect.succeed<Share>({
          id: "",
          url: "",
          secret: "",
        }),
      remove: (sessionID: SessionID) =>
        Effect.sync(() => {
          Database.use((db) =>
            db.delete(SessionShareTable).where(eq(SessionShareTable.session_id, sessionID)).run(),
          )
        }),
    }),
  )

  export const defaultLayer = layer
}
