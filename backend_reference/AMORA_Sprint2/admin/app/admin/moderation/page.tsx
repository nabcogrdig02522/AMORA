"use client";
import { useEffect, useState } from "react";
import { supabaseBrowser } from "../../../lib/supabase";

type Report = { id:string; reporter_id:string; reported_user_id:string; category:string; description:string|null; status:string; created_at:string };
type Verification = { id:string; user_id:string; verification_type:string; status:string; private_object_path:string|null; created_at:string };
export default function ModerationQueue() {
  const supabase = supabaseBrowser();
  const [reports,setReports] = useState<Report[]>([]);
  const [verifications,setVerifications] = useState<Verification[]>([]);
  const [error,setError] = useState("");
  const [loading,setLoading] = useState(true);
  async function load() {
    setLoading(true); setError("");
    const {data:{user}} = await supabase.auth.getUser();
    if (!user || user.app_metadata?.role !== "admin") { setError("Administrator access is required."); setLoading(false); return; }
    const [r,v] = await Promise.all([
      supabase.from("member_reports").select("id,reporter_id,reported_user_id,category,description,status,created_at").order("created_at",{ascending:false}).limit(100),
      supabase.from("verification_requests").select("id,user_id,verification_type,status,private_object_path,created_at").eq("status","pending").order("created_at",{ascending:false}).limit(100)
    ]);
    if (r.error || v.error) setError(r.error?.message ?? v.error?.message ?? "Unable to load queue.");
    setReports(r.data ?? []); setVerifications(v.data ?? []); setLoading(false);
  }
  useEffect(()=>{ void load(); },[]);
  async function updateReport(id:string,status:"reviewing"|"actioned"|"dismissed") {
    const note=window.prompt("Moderator note (do not include unnecessary sensitive information):")??"";
    const {error}=await supabase.rpc("admin_review_member_report",{p_report_id:id,p_status:status,p_note:note});
    if(error)setError(error.message);else await load();
  }
  async function updateVerification(id:string,status:"approved"|"rejected"|"needs_resubmission") {
    const note=window.prompt("Verification review note:")??"";
    const {error}=await supabase.rpc("admin_review_verification",{p_request_id:id,p_status:status,p_note:note});
    if(error)setError(error.message);else await load();
  }
  async function viewEvidence(path:string|null){
    if(!path){setError("No evidence object is attached to this request.");return;}
    const {data,error}=await supabase.storage.from("amora-verification").createSignedUrl(path,60);
    if(error){setError(error.message);return;} if(data?.signedUrl) window.open(data.signedUrl,"_blank","noopener,noreferrer");
  }
  return <main className="dashboard"><header><div><div className="wordmark">AMORA</div><span>Moderation queue</span></div><button className="secondary" onClick={()=>void load()}>Refresh</button></header>
    <h1>Trust & safety review</h1><p className="muted">Restricted moderation workspace. Review context before taking action and follow the internal escalation policy.</p>
    {error && <div className="notice">{error}</div>}{loading && <p>Loading queue…</p>}
    <section className="panel"><h2>Member reports ({reports.length})</h2>{reports.length===0?<p className="muted">No reports returned.</p>:reports.map(r=><article key={r.id} style={{borderTop:"1px solid #eee",padding:"14px 0"}}><strong>{r.category.replaceAll("_"," ")}</strong><p>Reported member: {r.reported_user_id}<br/>Reporter: {r.reporter_id}<br/>Status: {r.status}<br/>{r.description ?? "No additional details"}</p><div className="actions"><button onClick={()=>void updateReport(r.id,"reviewing")}>Reviewing</button><button onClick={()=>void updateReport(r.id,"actioned")}>Actioned</button><button className="secondary" onClick={()=>void updateReport(r.id,"dismissed")}>Dismiss</button></div></article>)}</section>
    <section className="panel"><h2>Pending verification requests ({verifications.length})</h2>{verifications.length===0?<p className="muted">No pending requests.</p>:verifications.map(v=><article key={v.id} style={{borderTop:"1px solid #eee",padding:"14px 0"}}><strong>{v.verification_type}</strong><p>Member: {v.user_id}<br/>Submitted: {new Date(v.created_at).toLocaleString()}<br/>Evidence is held in the private Supabase Storage bucket; no public URL is exposed here.</p><div className="actions"><button className="secondary" onClick={()=>void viewEvidence(v.private_object_path)}>View evidence (60 sec)</button><button onClick={()=>void updateVerification(v.id,"approved")}>Approve</button><button onClick={()=>void updateVerification(v.id,"needs_resubmission")}>Request resubmission</button><button className="secondary" onClick={()=>void updateVerification(v.id,"rejected")}>Reject</button></div></article>)}</section>
    <p className="muted">Review decisions are recorded through admin-only RPCs and written to the audit log. Evidence links expire after 60 seconds; access should still be restricted to trained reviewers under an approved retention policy.</p>
  </main>;
}
