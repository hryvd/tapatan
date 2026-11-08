import { useState } from "react";
import { ShieldCheck, Server, RefreshCw, OctagonAlert, LogOut, Pencil, ChevronRight, FlaskConical } from "lucide-react";
import { useApp } from "./store";
import { Btn, Sheet, Field } from "./ui";

export function ProfileScreen() {
  const { user, open, signOut, revoked, setRevoked, say } = useApp();
  const [dlg, setDlg] = useState(false);
  const [edit, setEdit] = useState(false);
  const [name, setName] = useState(user?.name ?? "");
  const rows = [
    { i: ShieldCheck, l: "JCOP4 Applet Security Info", s: "AID, Turing cipher, APDU table", fn: () => open({ type: "secinfo" }) },
    { i: FlaskConical, l: "Thesis security metrics", s: "CNN-LSTM, STRIDE, NFC key specs", fn: () => open({ type: "thesis" }) },
    { i: Server, l: "Account Backend & Rules", s: "Server URL, PIN policy, sync", fn: () => open({ type: "backend" }) },
    { i: RefreshCw, l: "Re-sync / Provision Card", s: "Write identity to the chip", fn: () => open({ type: "bind" }) },
  ];
  return (
    <div className="px-5 pt-2">
      <h1 className="text-white text-[24px] mb-3" style={{ fontWeight: 800 }}>Profile</h1>
      <div className="glass-tint p-4 flex items-center gap-3.5 mb-4">
        <span className="w-16 h-16 rounded-full btn-liquid text-white text-xl flex items-center justify-center" style={{ fontWeight: 800 }}>{name.split(" ").map((w) => w[0]).slice(0, 2).join("")}</span>
        <div className="flex-1 min-w-0">
          <p className="text-white text-[17px] truncate" style={{ fontWeight: 800 }}>{name}</p>
          <p className="text-white/60 text-[12px] truncate">{user?.email}</p>
          <p className={`font-mono-ui text-[10.5px] mt-1 ${revoked ? "text-[#F87171] line-through" : "text-cyan-200"}`}>{user?.uid}</p>
        </div>
        <button aria-label="Edit name" onClick={() => setEdit(true)} className="w-9 h-9 rounded-full glass-pill flex items-center justify-center text-white"><Pencil className="w-4 h-4" /></button>
      </div>
      {revoked && <p className="text-[#FCA5A5] text-[12px] bg-red-500/15 border border-red-400/30 rounded-2xl p-3 mb-4">This card UID is revoked. Payments are blocked until you re-provision.</p>}
      <p className="text-white/45 text-[11px] mb-2 ml-1 tracking-wider">HARDWARE &amp; SECURITY</p>
      <div className="glass divide-y divide-white/10 mb-4">
        {rows.map(({ i: I, l, s, fn }) => (
          <button key={l} onClick={fn} className="w-full flex items-center gap-3 px-4 py-3.5 text-left">
            <span className="w-9 h-9 rounded-[12px] bg-cyan-400/15 text-cyan-300 flex items-center justify-center"><I className="w-[18px] h-[18px]" /></span>
            <span className="flex-1"><span className="block text-white text-[13.5px]" style={{ fontWeight: 600 }}>{l}</span><span className="block text-white/45 text-[11px]">{s}</span></span>
            <ChevronRight className="w-4 h-4 text-white/35" />
          </button>
        ))}
        <button onClick={() => setDlg(true)} className="w-full flex items-center gap-3 px-4 py-3.5 text-left">
          <span className="w-9 h-9 rounded-[12px] bg-red-400/15 text-[#F87171] flex items-center justify-center"><OctagonAlert className="w-[18px] h-[18px]" /></span>
          <span className="flex-1 text-[#F87171] text-[13.5px]" style={{ fontWeight: 600 }}>Report Lost Card / Revoke UID</span>
        </button>
      </div>
      <Btn variant="glass" className="w-full" onClick={signOut}><LogOut className="w-4 h-4" />Sign Out</Btn>
      <p className="text-white/35 text-[11px] text-center mt-2">Balance, cards and history are saved to your account.</p>

      {dlg && (
        <Sheet title="Revoke this card?" onClose={() => setDlg(false)}>
          <p className="text-white/60 text-[13px] mb-4">UID <span className="font-mono-ui text-white">{user?.uid}</span> will be added to the revocation list and can no longer authorize payments.</p>
          <div className="flex gap-2"><Btn variant="glass" className="flex-1" onClick={() => setDlg(false)}>Cancel</Btn><Btn variant="danger" className="flex-1" onClick={() => { setRevoked(true); setDlg(false); say("Card revoked"); }}>Revoke</Btn></div>
        </Sheet>
      )}
      {edit && (
        <Sheet title="Edit name" onClose={() => setEdit(false)}>
          <Field label="Full name" value={name} onChange={(e) => setName(e.target.value)} />
          <Btn className="w-full" onClick={() => { setEdit(false); say("Name updated"); }}>Save</Btn>
        </Sheet>
      )}
    </div>
  );
}
