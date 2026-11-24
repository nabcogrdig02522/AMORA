import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function hmacSha512(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return [...new Uint8Array(signature)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const rawBody = await req.text();
  const supplied = req.headers.get("x-paystack-signature") ?? "";
  const secret = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  if (!secret) return new Response("Webhook not configured", { status: 503 });
  const expected = await hmacSha512(secret, rawBody);
  if (!constantTimeEqual(supplied.toLowerCase(), expected.toLowerCase())) return new Response("Invalid signature", { status: 401 });

  let event: any;
  try { event = JSON.parse(rawBody); }
  catch { return new Response("Invalid JSON", { status: 400 }); }
  if (event.event !== "charge.success") return new Response("Event ignored", { status: 200 });
  const reference = event.data?.reference;
  if (!reference) return new Response("Missing reference", { status: 400 });

  const url = Deno.env.get("SUPABASE_URL")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, service);
  const { data: intent } = await admin.from("payment_intents").select("*").eq("provider_reference", reference).maybeSingle();
  if (!intent) return new Response("Unknown reference", { status: 404 });
  if (intent.status === "success") return new Response("Already processed", { status: 200 });

  // Verify with Paystack server-to-server. The expected currency and amount come from
  // the immutable server-created intent, not the client or webhook payload.
  const verifyResponse = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
    headers: { Authorization: `Bearer ${secret}` },
  });
  const verified = await verifyResponse.json().catch(() => ({}));
  const tx = verified.data;
  const valid = verifyResponse.ok && verified.status && tx?.status === "success"
    && tx?.currency === intent.currency
    && Number(tx?.amount) === Number(intent.amount_minor)
    && tx?.reference === reference;
  if (!valid) {
    await admin.from("payment_intents").update({ status: "failed" }).eq("id", intent.id);
    return new Response("Transaction not verified", { status: 400 });
  }

  const { data: activation, error: activationError } = await admin.rpc("activate_subscription_for_payment", {
    p_intent_id: intent.id,
    p_provider_transaction_id: String(tx.id ?? ""),
    p_provider_payload: { channel: tx.channel, paid_at: tx.paid_at, gateway_transaction_id: tx.id },
  });
  if (activationError) {
    console.error("Subscription activation failed", activationError.message);
    return new Response("Could not activate entitlement", { status: 500 });
  }
  return new Response(activation === "already_processed" ? "Already processed" : "OK", { status: 200 });
});
