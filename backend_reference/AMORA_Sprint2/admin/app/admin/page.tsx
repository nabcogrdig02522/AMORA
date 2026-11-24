"use client";
import { useEffect, useState } from "react";
import { supabaseBrowser } from "../../lib/supabase";

type Counts = { users:number; pending:number; activeSubs:number; openReports:number };
export default function Admin() {
  const [counts,setCounts] = useState<Counts | null>(null);
  const [error,setError] = useState("");
  const [email,setEmail] = useState("");
  const supabase = supabaseBrowser();

  useEffect(() => {
    (async () => {
      const {data:{user}} = await supabase.auth.getUser();
      if (!user) { window.location.href="/"; return; }
      setEmail(user.email ?? "");
      if (user.app_metadata?.role !== "admin") { setError("This account is not assigned the administrator role."); return; }

      const [profiles,verify,subs,reports] = await Promise.all([
        supabase.from("profiles").select("id",{count:"exact",head:true}),
        supabase.from("verification_requests").select("id",{count:"exact",head:true}).eq("status","pending"),
        supabase.from("subscriptions").select("id",{count:"exact",head:true}).eq("status","active"),
        supabase.from("member_reports").select("id",{count:"exact",head:true}).eq("status","open")
      ]);
      const failed = [profiles,verify,subs,reports].find(x=>x.error);
      if (failed?.error) { setError(failed.error.message); return; }
      setCounts({users:profiles.count ?? 0,pending:verify.count ?? 0,activeSubs:subs.count ?? 0,openReports:reports.count ?? 0});
    })();
  }, []);

  async function signOut(){ await supabase.auth.signOut(); window.location.href="/"; }
  return <main className="dashboard">
    <header><div><div className="wordmark">AMORA</div><span>Founder Console</span></div><div>{email} <button className="secondary" onClick={signOut}>Sign out</button></div></header>
    <h1>Platform overview</h1>
    <p className="muted">Operational snapshot. Figures are loaded from access-controlled Supabase tables.</p>
    {error && <div className="notice">{error}</div>}
    {counts && <div className="stats">
      <article><span>Registered profiles</span><strong>{counts.users}</strong></article>
      <article><span>Pending verifications</span><strong>{counts.pending}</strong></article>
      <article><span>Active subscriptions</span><strong>{counts.activeSubs}</strong></article>
      <article><span>Open reports</span><strong>{counts.openReports}</strong></article>
    </div>}
    <section className="panel"><h2>Management modules</h2><ul>
      <li><a href="/admin/members">Member management — search, suspend, review and reactivate accounts</a></li>
      <li>Verification queue — review pending selfie / identity checks (restricted media workflow required)</li>
      <li>Payments — inspect payment intents and subscription status</li>
      <li><a href="/admin/moderation">Trust & safety — investigate reports and verification requests</a></li>
      <li><a href="/admin/analytics">Analytics — registrations, payment totals and subscription counts</a></li>
    </ul><p className="muted">Member status changes and report/verification reviews use admin-only database functions and audit records. Aggregates are provided for operational visibility; cohort retention and recognised revenue still require a validated event model and finance reconciliation.</p></section>
  </main>;
}
