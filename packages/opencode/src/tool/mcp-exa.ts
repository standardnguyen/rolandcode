import { Duration, Effect, Schema } from "effect"
import { HttpClient } from "effect/unstable/http"

// Stripped: upstream integrated an Exa Labs MCP endpoint as a first-class search tool.
// We do not want the user's queries forwarded to a third party by default.
// Call sites (websearch.ts, codesearch.ts) still compile, but receive no results.

export const SearchArgs = Schema.Struct({
  query: Schema.String,
  type: Schema.String,
  numResults: Schema.Number,
  livecrawl: Schema.String,
  contextMaxCharacters: Schema.optional(Schema.Number),
})

export const CodeArgs = Schema.Struct({
  query: Schema.String,
  tokensNum: Schema.Number,
})

export const call = <F extends Schema.Struct.Fields>(
  _http: HttpClient.HttpClient,
  _tool: string,
  _args: Schema.Struct<F>,
  _value: Schema.Struct.Type<F>,
  _timeout: Duration.Input,
) => Effect.succeed<string | undefined>(undefined)
