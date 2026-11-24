"use client";
import { useEffect, useState } from "react";
import { supabaseBrowser } from "../../../lib/supabase";
type Member={id:string;display_name:string|null;city:string|null;created_at:string;account_status:string;};
export default function Members(){
 const db=supabaseBrowser(); const [rows,setRows]=useState<Member[]>([]); const [q,setQ]=useState(""); const [msg,setMsg]=useState(""); const [busy,setBusy]=useState(false);
 async function load(){const {data:{user}}=await db.auth.getUser(); if(!user||user.app_metadata?.role!=="admin"){setMsg("Administrator access required.");return;}
  let req=db.from("profiles").select("id,display_name,city,created_at,account_status").order("created_at",{ascending:false}).limit(100);
  if(q.trim()) req=req.ilike("display_name",`%${q.trim()}%`); const {data,error}=await req; if(error)setMsg(error.message);else setRows((data??[]) as Member[]); }
 useEffect(()=>{load();},[]);
 async function change(id:string,status:string){const reason=window.prompt(`Reason for setting account to ${status}?`)??""; if(!reason.trim()&&status==="suspended")return; setBusy(true); const {error}=await db.rpc("admin_set_member_status",{p_member_id:id,p_status:status,p_reason:reason});setBusy(false);setMsg(error?.message??"Account status updated.");await load();}
 return <main className="dashboard"><header><div><div className="wordmark">AMORA</div><span>Member management</span></div><a href="/admin">Overview</a></header><h1>Members</h1><p className="muted">Search the latest 100 profiles. Status changes are audited and enforced through an admin-only database function.</p><input value={q} onChange={e=>setQ(e.target.value)} placeholder="Search display name"/><button onClick={load}>Search</button>{msg&&<p className="notice">{msg}</p>}<div className="panel"><table><thead><tr><th>Member</th><th>City</th><th>Joined</th><th>Status</th><th>Actions</th></tr></thead><tbody>{rows.map(m=><tr key={m.id}><td>{m.display_name??"—"}<small>{m.id}</small></td><td>{m.city??"—"}</td><td>{new Date(m.created_at).toLocaleDateString()}</td><td>{m.account_status??"active"}</td><td><button disabled={busy} onClick={()=>change(m.id,"suspended")}>Suspend</button> <button className="secondary" disabled={busy} onClick={()=>change(m.id,"active")}>Reactivate</button> <button className="secondary" disabled={busy} onClick={()=>change(m.id,"under_review")}>Review</button></td></tr>)}</tbody></table></div></main>;
}
