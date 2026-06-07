# `delete-account` Supabase Edge Function

Deliverable for the **backend repo** (not this iOS repo). The CookSavvy client calls this function from
`SupabaseAuthService.deleteAccount()` to satisfy App Store Guideline 5.1.1(v) (in-app account deletion).

## Contract

- **Name:** `delete-account`
- **Auth:** The client sends the user's session as `Authorization: Bearer <access_token>` (added
  automatically by `SupabaseClientProvider.invokeFunction`). The function identifies the user **from the
  token**, never from the request body. Body is an empty JSON object `{}`.
- **Behavior:** Validate the caller, delete their server-side data, then delete the auth user with the
  **service-role key** (server-side only — never shipped to the client).
- **Response:** `200 { "deleted": true }` on success; `401` if unauthenticated; `500` on failure.

## Source (`supabase/functions/delete-account/index.ts`)

```ts
// Supabase Edge Function (Deno runtime).
// Deploy: supabase functions deploy delete-account
// Required secrets (set via `supabase secrets set`):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const json = (status: number, body: unknown) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json(401, { error: "missing_authorization" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 1. Identify the caller from their JWT (anon client scoped to the caller's token).
    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !userData?.user) return json(401, { error: "invalid_session" });

    const userId = userData.user.id;

    // 2. Privileged client for deletion. Never expose the service-role key to clients.
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 3. Delete the user's server-side rows BEFORE deleting the auth user.
    //    Adjust table/column names to your schema. Prefer ON DELETE CASCADE FKs to user_id where possible.
    //    Example (uncomment + adapt):
    // await admin.from("user_recipes").delete().eq("user_id", userId);
    // await admin.from("cooking_sessions").delete().eq("user_id", userId);
    // await admin.from("shopping_items").delete().eq("user_id", userId);

    // 4. Delete the auth user (Admin API).
    const { error: delErr } = await admin.auth.admin.deleteUser(userId);
    if (delErr) return json(500, { error: "deletion_failed", detail: delErr.message });

    return json(200, { deleted: true });
  } catch (e) {
    // Log the error type/message server-side; do not echo sensitive details to the client.
    console.error("delete-account failed:", e instanceof Error ? e.name : "unknown");
    return json(500, { error: "internal_error" });
  }
});
```

## Security notes
- The **service-role key must only live in the Edge Function's environment** (Supabase secrets). It is
  never read by the iOS app and is not in `APIKeys.plist`.
- Deletion is keyed off the **verified JWT**, so a user can only delete their own account.
- Order matters: delete dependent rows (or rely on `ON DELETE CASCADE` foreign keys to `auth.users`)
  before/with the auth-user deletion to avoid orphaned data.

## After deploy
The iOS client already calls `delete-account` with the bearer token and empty body. No client change is
needed once this is deployed. Until it is deployed, the in-app "Delete Account" action will fail with a
network error (surfaced to the user as `Strings.Settings.deleteAccountFailed`).
