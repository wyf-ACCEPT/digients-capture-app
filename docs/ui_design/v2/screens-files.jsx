// screens-files.jsx — Submissions list, Recording Detail, Profile, Settings

const RECORDINGS = [
  // status: ondevice | uploading | review | approved | rejected
  // ondevice = recorded but user hasn't tapped Upload
  // uploading = upload in progress (user tapped Upload, transferring to R2)
  // review = uploaded; awaiting human moderation
  { id: 'r0', task: 'Pour water from a kettle into a mug', sessionId: 'a4f2c1d8', date: 'Today · 11:24', duration: '2:31', size: '283 MB', status: 'ondevice', points: 240 },
  { id: 'r1', task: 'Fold a bath towel into thirds',          sessionId: '550e8400', date: 'Today · 10:42', duration: '4:12', size: '467 MB', status: 'uploading', points: 320, uploadPct: 0.58 },
  { id: 'r2', task: 'Twist open a Nongfu Spring bottle cap',  sessionId: '6ba7b810', date: 'Today · 09:18', duration: '1:48', size: '202 MB', status: 'review',    points: 580 },
  { id: 'r3', task: 'Set the dinner table for two',           sessionId: '7c9e1d23', date: 'Yesterday',     duration: '6:33', size: '732 MB', status: 'approved',  points: 480 },
  { id: 'r4', task: 'Sort 10 hex bolts by size into bins',    sessionId: '8d3f4e56', date: 'Yesterday',     duration: '7:08', size: '795 MB', status: 'rejected',  points: 0, reason: 'Excessive motion blur' },
  { id: 'r5', task: 'Wipe down a kitchen counter',            sessionId: '9e5g6h78', date: '2d ago',        duration: '2:55', size: '326 MB', status: 'approved',  points: 220 },
];

const STATUS_LABELS = {
  ondevice: 'On Device',
  uploading: 'Uploading',
  review: 'In Review',
  approved: 'Approved',
  rejected: 'Rejected',
};

function SubmissionsScreen({ onNav, onRecording }) {
  const [tab, setTab] = React.useState('all');
  const totalSize = (RECORDINGS.reduce((acc, r) => acc + parseFloat(r.size), 0) / 1024).toFixed(2);
  const filtered = tab === 'all' ? RECORDINGS : RECORDINGS.filter(r => r.status === tab);

  const tabs = [
    { k: 'all',       label: 'All' },
    { k: 'ondevice',  label: 'On Device' },
    { k: 'uploading', label: 'Uploading' },
    { k: 'review',    label: 'In Review' },
    { k: 'approved',  label: 'Approved' },
    { k: 'rejected',  label: 'Rejected' },
  ];

  return (
    <div className="dg-screen">
      <TopStatus />
      <div style={{ padding: '12px 20px 8px' }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, letterSpacing: '-0.02em', margin: 0 }}>Submissions</h1>
        <div className="mono" style={{ fontSize: 12, color: 'var(--text-dim)', marginTop: 4 }}>
          {RECORDINGS.length} total · {totalSize} GB on device
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, padding: '12px 20px', overflow: 'auto', flex: '0 0 auto' }}>
        {tabs.map(t => (
          <div key={t.k} className={`chip ${tab === t.k ? 'active' : ''}`} onClick={() => setTab(t.k)}>
            {t.label}
          </div>
        ))}
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '4px 16px 20px' }}>
        {filtered.map((r, i) => (
          <RecordingRow key={r.id} rec={r} onClick={() => onRecording?.(r)} delay={i * 30}/>
        ))}
        {filtered.length === 0 && (
          <div style={{ textAlign: 'center', padding: '60px 20px', color: 'var(--text-faint)' }}>
            <div className="mono" style={{ fontSize: 11, letterSpacing: '0.14em', textTransform: 'uppercase' }}>No items</div>
          </div>
        )}
      </div>
      <TabBar active="files" onNav={onNav}/>
      <HomeIndicator />
    </div>
  );
}

function RecordingRow({ rec, onClick, delay = 0 }) {
  const statusLabel = STATUS_LABELS[rec.status];
  return (
    <div className="tap" onClick={onClick} style={{
      display: 'flex', gap: 12, padding: 12,
      background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 14,
      marginBottom: 10, animation: `fadeUp .4s ${delay}ms backwards`,
    }}>
      <div style={{ width: 76, height: 76, borderRadius: 10, overflow: 'hidden', flex: '0 0 auto', position: 'relative' }}>
        <div className="placeholder-img" style={{ width: '100%', height: '100%', borderRadius: 10 }}>
          <Icon.Camera size={20}/>
        </div>
        <div style={{ position: 'absolute', bottom: 4, right: 4, padding: '2px 5px', background: 'rgba(0,0,0,0.7)', borderRadius: 4 }}>
          <span className="mono" style={{ fontSize: 9, color: 'white' }}>{rec.duration}</span>
        </div>
        {rec.status === 'uploading' && (
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 10 }}>
            <div className="mono" style={{ fontSize: 11, color: 'white', fontWeight: 600 }}>{Math.round(rec.uploadPct * 100)}%</div>
          </div>
        )}
      </div>
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 14, fontWeight: 600, letterSpacing: '-0.01em', lineHeight: 1.3, marginBottom: 4, overflow: 'hidden', textOverflow: 'ellipsis', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
            {rec.task}
          </div>
          <div className="mono" style={{ fontSize: 10, color: 'var(--text-faint)' }}>
            {rec.date} · {rec.size}
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 6 }}>
          <span className={`status ${rec.status}`}>
            <span className="status-dot"/>{statusLabel}
          </span>
          {rec.points > 0 && rec.status === 'approved' && (
            <span className="mono" style={{ fontSize: 12, color: 'var(--accent)', fontWeight: 600 }}>+{rec.points}</span>
          )}
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', flex: '0 0 auto' }}>
        <RowAction rec={rec}/>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────
// RECORDING DETAIL — title is "Submissions"; supports all 5 statuses
// ──────────────────────────────────────────────
// inline upload / delete button on the right side of each list row.
// Stops propagation so tapping the icon doesn't open the detail page.
function RowAction({ rec }) {
  const stop = (e) => e.stopPropagation();
  if (rec.status === 'ondevice') {
    return (
      <button onClick={stop} aria-label="Upload" className="row-icon-btn upload">
        <Icon.Upload size={16}/>
      </button>
    );
  }
  if (rec.status === 'uploading') return null;
  // review | approved | rejected — already on server, can free local space
  return (
    <button onClick={stop} aria-label="Delete from device" className="row-icon-btn delete">
      <Icon.Trash size={16}/>
    </button>
  );
}

function RecordingDetailScreen({ rec, onBack }) {
  const r = rec || RECORDINGS[3];
  const statusLabel = STATUS_LABELS[r.status];

  return (
    <div className="dg-screen">
      <TopStatus />
      <NavBar title="Submissions" onBack={onBack}/>
      <div style={{ flex: 1, overflow: 'auto', padding: '12px 20px 32px' }}>
        <div style={{ position: 'relative' }}>
          <ImagePlaceholder label={`session_${r.sessionId.slice(0, 8)}`} height={210}/>
          <div style={{ position: 'absolute', bottom: 12, left: 12, padding: '4px 10px', background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(8px)', borderRadius: 6 }}>
            <span className="mono" style={{ fontSize: 11, color: 'white' }}>{r.duration}</span>
          </div>
        </div>

        <div style={{ marginTop: 18, marginBottom: 14 }}>
          <span className={`status ${r.status}`} style={{ fontSize: 12, padding: '6px 10px' }}>
            <span className="status-dot"/>{statusLabel}
          </span>
        </div>

        <h2 style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-0.02em', margin: '0 0 18px', lineHeight: 1.3, textWrap: 'balance' }}>{r.task}</h2>

        {/* Status block — varies by status */}
        <StatusBlock rec={r}/>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginBottom: 18 }}>
          <KV k="Session ID" v={`${r.sessionId}…`}/>
          <KV k="Captured" v={r.date}/>
          <KV k="Size" v={r.size}/>
          <KV k="Codec" v="HEVC · 15 Mb/s"/>
          <KV k="Resolution" v="1920×1080 · 30fps"/>
          <KV k="Intrinsics" v="Per-frame · ✓"/>
        </div>

        <ActionBar rec={r}/>
      </div>
      <HomeIndicator />
    </div>
  );
}

function StatusBlock({ rec: r }) {
  if (r.status === 'ondevice') {
    return (
      <div style={{ padding: 14, background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12, marginBottom: 18 }}>
        <div className="mono" style={{ fontSize: 10, color: 'var(--text-dim)', letterSpacing: '0.14em', textTransform: 'uppercase', marginBottom: 6 }}>Saved on device</div>
        <div style={{ fontSize: 13, lineHeight: 1.5, color: 'var(--text-dim)' }}>
          Not uploaded yet. Submit when on Wi-Fi to start the review process. Pending reward: <span className="mono" style={{ color: 'var(--accent)', fontWeight: 600 }}>+{r.points}</span>
        </div>
      </div>
    );
  }

  if (r.status === 'uploading') {
    const pct = Math.round((r.uploadPct || 0) * 100);
    return (
      <div style={{ padding: 14, background: 'var(--surface)', border: '1px solid var(--accent)', borderRadius: 12, marginBottom: 18 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <div className="mono" style={{ fontSize: 10, color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>Uploading…</div>
          <div className="mono" style={{ fontSize: 12, color: 'var(--text)', fontWeight: 600 }}>{pct}%</div>
        </div>
        <div style={{ height: 4, background: 'var(--surface-2)', borderRadius: 4, overflow: 'hidden', marginBottom: 8 }}>
          <div style={{ width: `${pct}%`, height: '100%', background: 'var(--accent)', transition: 'width 0.5s' }}/>
        </div>
        <div className="mono" style={{ fontSize: 11, color: 'var(--text-dim)' }}>
          ~{((parseFloat(r.size) * (1 - (r.uploadPct || 0))) / 8).toFixed(0)}s remaining · keep app foregrounded
        </div>
      </div>
    );
  }

  if (r.status === 'review') {
    return (
      <div style={{ padding: 14, background: 'var(--surface)', border: '1px solid rgba(255,214,10,0.35)', borderRadius: 12, marginBottom: 18 }}>
        <div className="mono" style={{ fontSize: 10, color: 'var(--warning)', letterSpacing: '0.14em', textTransform: 'uppercase', marginBottom: 6 }}>In review</div>
        <div style={{ fontSize: 13, lineHeight: 1.5, color: 'var(--text-dim)' }}>
          Submitted. Approval typically takes ~48 hours. Pending: <span className="mono" style={{ color: 'var(--accent)', fontWeight: 600 }}>+{r.points}</span>
        </div>
      </div>
    );
  }

  if (r.status === 'approved') {
    return (
      <div style={{ padding: 14, background: 'rgba(20,201,168,0.06)', border: '1px solid rgba(20,201,168,0.3)', borderRadius: 12, marginBottom: 18, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div className="mono" style={{ fontSize: 10, color: 'var(--success)', letterSpacing: '0.14em', textTransform: 'uppercase', marginBottom: 4 }}>Credited</div>
          <div style={{ fontSize: 13, color: 'var(--text-dim)' }}>Settled to your balance</div>
        </div>
        <div className="mono" style={{ fontSize: 22, fontWeight: 700, color: 'var(--accent)' }}>+{r.points}</div>
      </div>
    );
  }

  if (r.status === 'rejected') {
    return (
      <div style={{ padding: 14, background: 'rgba(255,69,58,0.08)', border: '1px solid rgba(255,69,58,0.3)', borderRadius: 12, marginBottom: 18 }}>
        <div className="mono" style={{ fontSize: 10, color: 'var(--danger)', letterSpacing: '0.14em', textTransform: 'uppercase', marginBottom: 6 }}>Rejection reason</div>
        <div style={{ fontSize: 13, lineHeight: 1.5 }}>{r.reason}. Try again with steadier hand and bright, even lighting.</div>
      </div>
    );
  }
  return null;
}

function ActionBar({ rec: r }) {
  // Action sets per status:
  //  - ondevice : [Upload primary] [Delete]
  //  - uploading: [Pause secondary disabled] [Cancel danger]
  //  - review   : [Delete from device] only (server has it)
  //  - approved : [Delete from device]   only (server has it)
  //  - rejected : [Delete from device]   only
  if (r.status === 'ondevice') {
    return (
      <div style={{ display: 'flex', gap: 10 }}>
        <button className="cta" style={{ flex: 1, display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'center' }}>
          <Icon.Upload size={18}/> Upload
        </button>
        <button className="cta-secondary" style={{ flex: '0 0 56px', padding: 0, color: 'var(--danger)' }} aria-label="Delete">
          <Icon.Trash size={20}/>
        </button>
      </div>
    );
  }
  if (r.status === 'uploading') {
    return (
      <div style={{ display: 'flex', gap: 10 }}>
        <button className="cta-secondary" style={{ flex: 1, display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'center' }}>
          Pause
        </button>
        <button className="cta-secondary" style={{ flex: 1, color: 'var(--danger)' }}>Cancel upload</button>
      </div>
    );
  }
  // server-side states: only delete-from-device
  return (
    <div style={{ display: 'flex', gap: 10 }}>
      <button className="cta-secondary" style={{ flex: 1, display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'center', color: 'var(--danger)' }}>
        <Icon.Trash size={18}/> Delete from device
      </button>
    </div>
  );
}

function KV({ k, v }) {
  return (
    <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '10px 12px' }}>
      <div className="mono" style={{ fontSize: 9, color: 'var(--text-dim)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>{k}</div>
      <div className="mono" style={{ fontSize: 12, fontWeight: 500, marginTop: 3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{v}</div>
    </div>
  );
}

// ──────────────────────────────────────────────
// PROFILE — radar + leaderboard
// ──────────────────────────────────────────────
function ProfileScreen({ onNav, onSettings }) {
  const dims = [
    { name: 'Household', value: 0.85 },
    { name: 'Industrial', value: 0.42 },
    { name: 'Sports', value: 0.6 },
    { name: 'Variety', value: 0.78 },
    { name: 'Speed', value: 0.55 },
    { name: 'Approval', value: 0.91 },
  ];

  return (
    <div className="dg-screen">
      <TopStatus />
      <div style={{ flex: 1, overflow: 'auto', paddingBottom: 20 }}>
        <div style={{ padding: '20px 20px 24px', display: 'flex', gap: 14, alignItems: 'center' }}>
          <div style={{
            width: 64, height: 64, borderRadius: '50%',
            background: 'linear-gradient(135deg, #14C9A8, #45E0BA)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'white', fontWeight: 700, fontSize: 22, flex: '0 0 auto',
          }}>MC</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-0.02em' }}>Maya Chen</div>
            <div className="mono" style={{ fontSize: 11, color: 'var(--text-dim)', marginTop: 2 }}>UID · DGT-A47K3PX9</div>
          </div>
          <button onClick={onSettings} className="tap" style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12, padding: 10, color: 'var(--text)', cursor: 'pointer' }} aria-label="Settings">
            <Icon.Settings size={18}/>
          </button>
        </div>

        <div style={{ padding: '0 20px 20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 14, padding: 14 }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--text-dim)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>Balance</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 4 }}>
              <span className="mono" style={{ fontSize: 26, fontWeight: 700, letterSpacing: '-0.02em' }}>4,280</span>
              <span style={{ fontSize: 12, color: 'var(--text-dim)' }}>pts</span>
            </div>
          </div>
          <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 14, padding: 14 }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--text-dim)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>Pending</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 4 }}>
              <span className="mono" style={{ fontSize: 26, fontWeight: 700, color: 'var(--warning)', letterSpacing: '-0.02em' }}>1,500</span>
              <span style={{ fontSize: 12, color: 'var(--text-dim)' }}>pts</span>
            </div>
          </div>
        </div>

        <div style={{ padding: '0 20px 24px' }}>
          <div className="mono" style={{ fontSize: 11, color: 'var(--text-dim)', letterSpacing: '0.16em', textTransform: 'uppercase', marginBottom: 12 }}>Contributions</div>
          <div style={{ display: 'flex', justifyContent: 'space-between', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 14, padding: '14px 12px' }}>
            <Stat3 v="14.2" label="Hours"/>
            <div style={{ width: 1, background: 'var(--border)' }}/>
            <Stat3 v="38" label="Submitted"/>
            <div style={{ width: 1, background: 'var(--border)' }}/>
            <Stat3 v="91%" label="Approval"/>
          </div>
        </div>

        <div style={{ padding: '0 20px 24px' }}>
          <div className="mono" style={{ fontSize: 11, color: 'var(--text-dim)', letterSpacing: '0.16em', textTransform: 'uppercase', marginBottom: 12 }}>Capability</div>
          <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 18, padding: '18px 14px 8px', display: 'flex', justifyContent: 'center' }}>
            <Radar dims={dims}/>
          </div>
        </div>

        <div style={{ padding: '0 20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 12 }}>
            <span className="mono" style={{ fontSize: 11, color: 'var(--text-dim)', letterSpacing: '0.16em', textTransform: 'uppercase' }}>Leaderboard · Global</span>
            <span className="mono" style={{ fontSize: 11, color: 'var(--accent)' }}>You · #247</span>
          </div>
          <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 14, overflow: 'hidden' }}>
            {[
              { rank: 1, name: 'kenji_99',   hours: '142.8', pts: '48,210', isMe: false },
              { rank: 2, name: 'lia.dee',    hours: '128.5', pts: '42,180', isMe: false },
              { rank: 3, name: 'mr_robot',   hours: '119.2', pts: '39,950', isMe: false },
              { rank: 247, name: 'You',      hours: '14.2',  pts: '4,280',  isMe: true  },
              { rank: 248, name: 'sandra.k', hours: '14.0',  pts: '4,210',  isMe: false },
            ].map((row, i) => (
              <div key={row.rank} style={{
                display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px',
                borderBottom: i < 4 ? '1px solid var(--border)' : 'none',
                background: row.isMe ? 'var(--accent-tint)' : 'transparent',
              }}>
                <div className="mono" style={{ width: 36, fontSize: 13, color: row.rank <= 3 ? 'var(--accent)' : 'var(--text-dim)', fontWeight: 600 }}>
                  {row.rank <= 3 ? `0${row.rank}` : `#${row.rank}`}
                </div>
                <div style={{ flex: 1, fontSize: 14, fontWeight: row.isMe ? 600 : 500 }}>{row.name}</div>
                <div className="mono" style={{ fontSize: 11, color: 'var(--text-dim)', width: 60, textAlign: 'right' }}>{row.hours}h</div>
                <div className="mono" style={{ fontSize: 12, color: 'var(--accent)', fontWeight: 600, width: 60, textAlign: 'right' }}>{row.pts}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
      <TabBar active="me" onNav={onNav}/>
      <HomeIndicator />
    </div>
  );
}

function Stat3({ v, label }) {
  return (
    <div style={{ flex: 1, textAlign: 'center', padding: '0 4px' }}>
      <div className="mono" style={{ fontSize: 20, fontWeight: 700, letterSpacing: '-0.02em' }}>{v}</div>
      <div className="mono" style={{ fontSize: 9, color: 'var(--text-dim)', letterSpacing: '0.14em', textTransform: 'uppercase', marginTop: 2 }}>{label}</div>
    </div>
  );
}

function Radar({ dims }) {
  const cx = 130, cy = 130, R = 90;
  const n = dims.length;
  const pt = (i, r) => {
    const a = (Math.PI * 2 * i / n) - Math.PI / 2;
    return [cx + Math.cos(a) * r, cy + Math.sin(a) * r];
  };
  const valuePts = dims.map((d, i) => pt(i, R * d.value));
  const path = valuePts.map((p, i) => `${i === 0 ? 'M' : 'L'}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' ') + ' Z';

  return (
    <svg width="260" height="260" viewBox="0 0 260 260">
      {[0.25, 0.5, 0.75, 1].map(r => {
        const pts = dims.map((_, i) => pt(i, R * r).join(',')).join(' ');
        return <polygon key={r} points={pts} fill="none" stroke="var(--border-strong)" strokeWidth="1" opacity="0.5"/>;
      })}
      {dims.map((_, i) => {
        const [x, y] = pt(i, R);
        return <line key={i} x1={cx} y1={cy} x2={x} y2={y} stroke="var(--border)" strokeWidth="1"/>;
      })}
      <path d={path} fill="var(--accent)" fillOpacity="0.2" stroke="var(--accent)" strokeWidth="1.5" strokeLinejoin="round"/>
      {valuePts.map((p, i) => <circle key={i} cx={p[0]} cy={p[1]} r="3" fill="var(--accent)"/>)}
      {dims.map((d, i) => {
        const [x, y] = pt(i, R + 22);
        return (
          <text key={i} x={x} y={y} textAnchor="middle" dominantBaseline="middle" fontSize="11" fontFamily="JetBrains Mono" fill="var(--text)" fontWeight="500">
            {d.name}
          </text>
        );
      })}
    </svg>
  );
}

// ──────────────────────────────────────────────
// SETTINGS
// ──────────────────────────────────────────────
function SettingsScreen({ onBack }) {
  const sections = [
    { title: 'Account', items: [
      { label: 'Avatar', avatar: true, initials: 'MC' },
      { label: 'Email', value: 'maya.chen@gmail.com' },
      { label: 'Phone', value: '+1 (415) ••• 4729' },
      { label: 'UID',   value: 'DGT-A47K3PX9', mono: true },
    ]},
    { title: 'Uploads', items: [
      { label: 'Upload over Wi-Fi only', toggle: true, on: true },
      { label: 'Auto-upload after capture', toggle: true, on: true },
      { label: 'Background uploads',     toggle: true, on: true },
    ]},
    { title: 'Notifications', items: [
      { label: 'Approval results', toggle: true, on: true },
      { label: 'Points credited',  toggle: true, on: true },
    ]},
    { title: 'Appearance', items: [
      { label: 'Theme', segmented: true, options: [
        { value: 'auto',  label: 'Auto' },
        { value: 'dark',  label: 'Dark' },
        { value: 'light', label: 'Light' },
      ], default: 'auto' },
    ]},
    { title: 'About', items: [
      { label: 'Version',          value: '2.0.1 (build 4218)', mono: true },
      { label: 'Privacy Policy',   chev: true },
      { label: 'Terms of Service', chev: true },
      { label: 'Open-source licenses', chev: true },
    ]},
    { title: '', items: [
      { label: 'Sign Out', danger: true },
      { label: 'Delete account', danger: true },
    ]},
  ];

  return (
    <div className="dg-screen">
      <TopStatus />
      <NavBar title="Settings" onBack={onBack}/>
      <div style={{ flex: 1, overflow: 'auto', padding: '8px 0 32px' }}>
        {sections.map((sec, si) => (
          <div key={si} style={{ marginBottom: 22 }}>
            {sec.title && (
              <div className="mono" style={{ fontSize: 10, color: 'var(--text-dim)', letterSpacing: '0.16em', textTransform: 'uppercase', padding: '8px 20px 8px' }}>
                {sec.title}
              </div>
            )}
            <div style={{ background: 'var(--surface)', borderTop: '1px solid var(--border)', borderBottom: '1px solid var(--border)' }}>
              {sec.items.map((it, i) => (
                <SettingsRow key={i} item={it} divider={i < sec.items.length - 1}/>
              ))}
            </div>
          </div>
        ))}
      </div>
      <HomeIndicator />
    </div>
  );
}

function SettingsRow({ item, divider }) {
  const [on, setOn] = React.useState(!!item.on);
  return (
    <div className="tap" style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '14px 20px',
      borderBottom: divider ? '1px solid var(--border)' : 'none',
      cursor: item.toggle ? 'default' : 'pointer',
    }}>
      <div style={{
        flex: 1, fontSize: 15, fontWeight: 500,
        color: item.danger ? 'var(--danger)' : 'var(--text)',
      }}>{item.label}</div>
      {item.avatar && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            width: 36, height: 36, borderRadius: '50%',
            background: 'linear-gradient(135deg, var(--accent), color-mix(in oklch, var(--accent) 50%, #6366f1))',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'white', fontWeight: 600, fontSize: 13, letterSpacing: '0.02em',
          }}>{item.initials}</div>
          <span className="mono" style={{ fontSize: 11, color: 'var(--text-dim)', letterSpacing: '0.12em', textTransform: 'uppercase' }}>Change</span>
        </div>
      )}
      {item.value && (
        <div className={item.mono ? 'mono' : ''} style={{ fontSize: 13, color: 'var(--text-dim)', letterSpacing: item.mono ? 0 : '-0.01em' }}>
          {item.value}
        </div>
      )}
      {item.toggle && (
        <button onClick={() => setOn(v => !v)}
          className={`switch ${on ? 'on' : ''}`}
          aria-pressed={on}
          aria-label={item.label}
        ><i /></button>
      )}
      {item.chev && <Icon.ChevronRight size={16} color="var(--text-faint)"/>}
      {item.segmented && <SettingsSegmented item={item}/>}
    </div>
  );
}

function SettingsSegmented({ item }) {
  const [val, setVal] = React.useState(item.default);
  return (
    <div style={{
      display: 'flex', gap: 2, padding: 3,
      background: 'var(--surface-2)', borderRadius: 9,
    }}>
      {item.options.map(o => (
        <button
          key={o.value}
          onClick={(e) => { e.stopPropagation(); setVal(o.value); }}
          style={{
            border: 'none', cursor: 'pointer',
            padding: '6px 10px', borderRadius: 7,
            background: val === o.value ? 'var(--surface)' : 'transparent',
            color: val === o.value ? 'var(--text)' : 'var(--text-dim)',
            fontSize: 12, fontWeight: 500, letterSpacing: '-0.005em',
            boxShadow: val === o.value ? '0 1px 2px rgba(0,0,0,0.18)' : 'none',
            transition: 'all 0.15s ease',
          }}
        >{o.label}</button>
      ))}
    </div>
  );
}

Object.assign(window, { SubmissionsScreen, RecordingDetailScreen, ProfileScreen, SettingsScreen, RECORDINGS, STATUS_LABELS });
