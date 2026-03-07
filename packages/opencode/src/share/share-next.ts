import { Database, eq } from "@/storage/db"
import { SessionShareTable } from "./share.sql"

export namespace ShareNext {
  export async function url() {
    return ""
  }

  export async function init() {}

  export async function create(_sessionID: string) {
    return { id: "", url: "", secret: "" }
  }

  export async function remove(sessionID: string) {
    Database.use((db) => db.delete(SessionShareTable).where(eq(SessionShareTable.session_id, sessionID)).run())
  }
}
