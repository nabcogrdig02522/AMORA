"use client";
import { useState } from "react";
import { supabaseBrowser } from "../lib/supabase";

export default function Home() {
  const [email,setEmail] = useState("");
  const [password,setPassword] = useState("");
  const [message,setMessage] = useState("");
  const [busy,setBusy] = useState(false);
  const supabase = supabaseBrowser();

  async function signIn(e: React.FormEvent) {
    e.preventDefault(); setBusy(true); setMessage("");
    const {error} = await supabase.auth.signInWithPassword({email,password});
    setMessage(error ? error.message : "Signed in. Opening founder console…");
    if (!error) window.location.href = "/admin";
    setBusy(false);
  }
  return <main className="shell">
    <section className="brand"><div className="wordmark">AMORA</div><p>Founder Console</p><span>More than a match. A meaningful connection.</span></section>
    <form className="panel" onSubmit={signIn}>
      <h1>Administrator sign in</h1>
      <label>Email<input type="email" required value={email} onChange={e=>setEmail(e.target.value)} /></label>
      <label>Password<input type="password" required value={password} onChange={e=>setPassword(e.target.value)} /></label>
      <button disabled={busy}>{busy ? "Signing in…" : "Sign in securely"}</button>
      {message && <p role="status">{message}</p>}
      <small>Access is restricted by Supabase authentication and database row-level security. An ordinary member account is not an administrator.</small>
    </form>
  </main>;
}
