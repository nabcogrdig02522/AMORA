import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": Deno.env.get("APP_ORIGIN") ?? "https://your-amora-domain.example",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers: cors });

  const auth = req.headers.get("Authorization");
  if (!auth) return Response.json({ error: "Authentication required" }, { status: 401, headers: cors });

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return Response.json({ error: "Backend is not configured" }, { status: 503, headers: cors });

  const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return Response.json({ error: "Invalid session" }, { status: 401, headers: cors });

  const body = await req.json().catch(() => null);
  const planCode = body?.plan_code as string;
  if (!["plus", "premium", "elite"].includes(planCode)) return Response.json({ error: "Invalid plan" }, { status: 400, headers: cors });

  const admin = createClient(url, service);
  const { data: profile, error: profileError } = await admin.from("profiles")
    .select("country_code,account_status").eq("id", user.id).maybeSingle();
  if (profileError || !profile?.country_code) return Response.json({ error: "Member market is not configured" }, { status: 400, headers: cors });
  if (profile.account_status && profile.account_status !== "active") return Response.json({ error: "This account cannot make purchases" }, { status: 403, headers: cors });

  const countryCode = String(profile.country_code).toUpperCase();
  const { data: market } = await admin.from("regional_market_config")
    .select("launch_status").eq("country_code", countryCode).maybeSingle();
  if (!market || !["pilot", "enabled"].includes(market.launch_status)) {
    return Response.json({ error: "Subscriptions are not available in this market yet" }, { status: 403, headers: cors });
  }

  const now = new Date().toISOString();
  const { data: price, error: priceError } = await admin.from("market_plan_prices")
    .select("amount_minor,currency_code,billing_days,provider_code")
    .eq("country_code", countryCode).eq("plan_code", planCode).eq("enabled", true)
    .lte("effective_from", now)
    .or(`effective_to.is.null,effective_to.gt.${now}`)
    .order("effective_from", { ascending: false }).limit(1).maybeSingle();
  if (priceError || !price) return Response.json({ error: "This plan is not available in your market" }, { status: 403, headers: cors });
  if (!user.email) return Response.json({ error: "An email address is required for checkout" }, { status: 400, headers: cors });

  // This sprint enables only the existing Ghana Paystack rail. Other provider adapters
  // must be separately implemented and reviewed before enabling their market prices.
  if (countryCode !== "GH" || price.provider_code !== "paystack" || price.currency_code !== "GHS") {
    return Response.json({ error: "Payment provider is not yet enabled for this market" }, { status: 503, headers: cors });
  }

  const secret = Deno.env.get("PAYSTACK_SECRET_KEY");
  if (!secret) return Response.json({ error: "Payment service is not configured" }, { status: 503, headers: cors });

  const reference = `amora_${crypto.randomUUID().replaceAll("-", "")}`;
  const { data: intent, error: insertError } = await admin.from("payment_intents").insert({
    user_id: user.id, plan_code: planCode, amount_minor: price.amount_minor,
    currency: price.currency_code, country_code: countryCode, market_currency: price.currency_code,
    plan_days: price.billing_days, provider: price.provider_code,
    provider_reference: reference, status: "initialized",
  }).select("id").single();
  if (insertError) return Response.json({ error: "Could not create payment record" }, { status: 500, headers: cors });

  const callback = Deno.env.get("APP_CHECKOUT_URL");
  const payload = {
    email: user.email, amount: price.amount_minor, currency: price.currency_code,
    reference, callback_url: callback, channels: ["card", "mobile_money"],
    metadata: { user_id: user.id, payment_intent_id: intent.id, plan_code: planCode, country_code: countryCode },
  };

  const response = await fetch("https://api.paystack.co/transaction/initialize", {
    method: "POST",
    headers: { Authorization: `Bearer ${secret}`, "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok || !result.status || !result.data?.authorization_url) {
    await admin.from("payment_intents").update({ status: "failed", provider_payload: { message: "Initialization failed" } }).eq("id", intent.id);
    return Response.json({ error: "Payment initialization failed" }, { status: 502, headers: cors });
  }

  await admin.from("payment_intents").update({
    status: "pending", checkout_url: result.data.authorization_url,
    provider_payload: { access_code: result.data.access_code },
  }).eq("id", intent.id);

  return Response.json({
    payment_intent_id: intent.id, reference,
    authorization_url: result.data.authorization_url,
    amount_minor: price.amount_minor, currency: price.currency_code,
    country_code: countryCode, billing_days: price.billing_days,
  }, { headers: cors });
});
