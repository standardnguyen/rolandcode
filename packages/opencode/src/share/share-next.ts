import { Database, eq } from "@/storage/db"
import { SessionShareTable } from "./share.sql"
import type { SessionID } from "@/session/schema"

export namespace ShareNext {
  export async function url() {
    return ""
  }

  export async function init() {
    // Stripped: no session sharing
  }

  export async function create(_sessionID: SessionID) {
    return { id: "", url: "", secret: "" }
  }

  export async function remove(sessionID: SessionID) {
    Database.use((db) => db.delete(SessionShareTable).where(eq(SessionShareTable.session_id, sessionID)).run())
  }
}
