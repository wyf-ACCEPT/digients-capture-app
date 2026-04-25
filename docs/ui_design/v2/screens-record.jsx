// screens-record.jsx — Task Detail, Recording, Submit Success

function TaskDetailScreen({ task, onBack, onRecord }) {
  // Per V2: bitrate per spec (15 Mbps HEVC), 5% headroom, derived from free storage.
  // 15 Mbps ≈ 112.5 MB/min. Assume free=18 GB → usable=17.1 GB → ~155 min.
  const freeGB = 18.0;
  const usable = freeGB * 0.95;
  const minutes = Math.floor(usable * 1024 / 112.5);
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  const t = task || { title: 'Twist open a Nongfu Spring bottle cap', publisher: 'Robofactory Lab', points: 580, dur: '1-2 min', tag: 'Manipulation' };

  return (
    <div className="dg-screen">
      <TopStatus />
      <NavBar title="Task Details" onBack={onBack}/>
      <div style={{ flex: 1, overflow: 'auto', paddingBottom: 130 }}>
        <div style={{ padding: '4px 20px 0' }}>
          <ImagePlaceholder label="Demo · 0:08" height={200}/>
        </div>

        <div style={{ padding: '20px 20px 0' }}>
          <h1 style={{ fontSize: 26, fontWeight: 700, letterSpacing: '-0.02em', lineHeight: 1.2, margin: '0 0 14px', textWrap: 'balance' }}>{t.title}</h1>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 4, flexWrap: 'wrap' }}>
            <Icon.Bolt size={20}/>
            <span className="mono" style={{ fontSize: 36, fontWeight: 700, color: 'var(--accent)', letterSpacing: '-0.03em' }}>+{t.points}</span>
            <span style={{ fontSize: 13, color: 'var(--text-dim)', letterSpacing: '-0.01em' }}>points on approval, per task duration</span>
          </div>
        </div>

        <div style={{ padding: '20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <Spec icon={<Icon.Clock size={16}/>} label="Task Duration" value={t.dur}/>
          <Spec icon={<Icon.Bolt size={16}/>} label="Difficulty" value="Easy"/>
          <Spec icon={<Icon.Camera size={16}/>} label="Lighting" value="Bright, even"/>
          <Spec icon={<Icon.Storage size={16}/>} label="Surface" value="Stable, level"/>
        </div>

        <div style={{ padding: '0 20px 20px' }}>
          <div className="mono" style={{ fontSize: 11, color: 'var(--text-dim)', letterSpacing: '0.16em', textTransform: 'uppercase', marginBottom: 12 }}>Steps</div>
          {[
            'Pick up the bottle with one hand',
            'Twist open the cap with the other',
            'Pour a small amount into the cup',
            'Reset the scene and repeat',
          ].map((s, i) => (
            <div key={i} style={{ display: 'flex', gap: 14, padding: '10px 0', borderBottom: i < 3 ? '1px solid var(--border)' : 'none' }}>
              <div style={{
                width: 24, height: 24, borderRadius: '50%', background: 'var(--surface-2)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 12, fontWeight: 600, fontFamily: 'JetBrains Mono', flex: '0 0 auto',
              }}>{i + 1}</div>
              <div style={{ fontSize: 14, lineHeight: 1.5, flex: 1 }}>{s}</div>
            </div>
          ))}
        </div>

        <div style={{ margin: '0 20px 24px', padding: 14, background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 14 }}>
          <div className="mono" style={{ fontSize: 10, color: 'var(--text-dim)', letterSpacing: '0.14em', textTransform: 'uppercase', marginBottom: 8 }}>Heads up</div>
          <div style={{ fontSize: 13, lineHeight: 1.5, color: 'var(--text-dim)' }}>
            Recording will <span style={{ color: 'var(--text)' }}>auto-stop</span> at 5% remaining storage. Phone will buzz to alert you.
          </div>
        </div>
      </div>

      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        padding: '14px 20px 28px',
        background: 'linear-gradient(to top, var(--bg) 85%, transparent)',
        zIndex: 5,
      }}>
        <div style={{ textAlign: 'center', marginBottom: 10 }}>
          <span className="mono" style={{ fontSize: 11, color: 'var(--text-dim)' }}>
            Able to record <span style={{ color: 'var(--text)' }}>{hours}h {String(mins).padStart(2, '0')}m</span> on device
          </span>
        </div>
        <button className="cta" onClick={onRecord} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10 }}>
          <span style={{ width: 12, height: 12, borderRadius: '50%', background: 'white' }}/>
          Record
        </button>
      </div>
      <HomeIndicator />
    </div>
  );
}

function Spec({ icon, label, value }) {
  return (
    <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12, padding: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--text-dim)', marginBottom: 4 }}>
        {icon}
        <span className="mono" style={{ fontSize: 10, letterSpacing: '0.14em', textTransform: 'uppercase' }}>{label}</span>
      </div>
      <div style={{ fontSize: 14, fontWeight: 500, letterSpacing: '-0.01em' }}>{value}</div>
    </div>
  );
}

function RecordingScreen({ onStop, task }) {
  const [secs, setSecs] = React.useState(0);
  const [hudOpen, setHudOpen] = React.useState(false);
  const t = task || { title: 'Twist open a Nongfu Spring bottle cap', points: 580 };

  React.useEffect(() => {
    const id = setInterval(() => setSecs(s => s + 1), 1000);
    return () => clearInterval(id);
  }, []);

  const fmt = n => `${String(Math.floor(n / 60)).padStart(2, '0')}:${String(n % 60).padStart(2, '0')}`;
  const storagePct = Math.max(5, 95 - secs * 0.05);

  return (
    <div className="dg-screen" style={{ background: '#000' }}>
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(circle at 50% 60%, rgba(40,40,45,1) 0%, rgba(8,8,10,1) 100%)' }}/>
      <svg style={{ position: 'absolute', inset: 0, opacity: 0.08 }} width="100%" height="100%">
        <line x1="33%" y1="0" x2="33%" y2="100%" stroke="white"/>
        <line x1="67%" y1="0" x2="67%" y2="100%" stroke="white"/>
        <line x1="0" y1="33%" x2="100%" y2="33%" stroke="white"/>
        <line x1="0" y1="67%" x2="100%" y2="67%" stroke="white"/>
      </svg>
      <div style={{ position: 'absolute', left: '50%', top: '60%', transform: 'translate(-50%, -50%)', opacity: 0.18, color: 'white' }}>
        <svg width="180" height="200" viewBox="0 0 180 200" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round">
          <ellipse cx="90" cy="120" rx="40" ry="18"/>
          <path d="M50 80 q40 -30 80 0 v40 q-40 30 -80 0 z"/>
        </svg>
      </div>

      <TopStatus dark={true}/>

      <div style={{ position: 'absolute', top: 56, left: 0, right: 0, display: 'flex', justifyContent: 'center', zIndex: 3 }}>
        <div onClick={() => setHudOpen(v => !v)} className="tap" style={{
          display: 'flex', alignItems: 'center', gap: 10,
          padding: '10px 16px', background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(20px)',
          borderRadius: 999, border: '1px solid rgba(255,255,255,0.1)',
        }}>
          <span className="rec-dot"/>
          <span className="mono" style={{ fontSize: 16, fontWeight: 600, color: 'white', letterSpacing: '-0.02em' }}>{fmt(secs)}</span>
        </div>
      </div>

      {hudOpen && (
        <div style={{
          position: 'absolute', top: 110, left: 16, right: 16, zIndex: 3,
          background: 'rgba(0,0,0,0.65)', backdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.1)', borderRadius: 16,
          padding: 14, animation: 'fadeUp .25s',
        }}>
          <div style={{ fontSize: 13, fontWeight: 500, color: 'white', marginBottom: 8, letterSpacing: '-0.01em' }}>{t.title}</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
            <Stat label="FPS" value="30"/>
            <Stat label="Codec" value="HEVC"/>
            <Stat label="Lens" value="Ultrawide"/>
            <Stat label="Bitrate" value="15 Mb/s"/>
            <Stat label="Stab" value="OFF"/>
            <Stat label="Intrinsics" value="LIVE" color="var(--success)"/>
          </div>
          <div style={{ marginTop: 12, paddingTop: 12, borderTop: '1px solid rgba(255,255,255,0.1)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
              <span className="mono" style={{ fontSize: 10, color: 'rgba(255,255,255,0.6)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>Storage</span>
              <span className="mono" style={{ fontSize: 10, color: 'rgba(255,255,255,0.6)' }}>{storagePct.toFixed(1)}%</span>
            </div>
            <div style={{ height: 4, background: 'rgba(255,255,255,0.1)', borderRadius: 4, overflow: 'hidden' }}>
              <div style={{ width: `${storagePct}%`, height: '100%', background: storagePct < 15 ? 'var(--accent)' : 'white', transition: 'width 0.5s' }}/>
            </div>
          </div>
        </div>
      )}

      <div style={{ position: 'absolute', bottom: 60, left: 0, right: 0, display: 'flex', justifyContent: 'center', zIndex: 3 }}>
        <button onClick={onStop} className="tap" style={{
          width: 80, height: 80, borderRadius: '50%',
          background: 'transparent', border: '4px solid white', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 0,
        }}>
          <div style={{ width: 30, height: 30, background: 'var(--accent)', borderRadius: 6 }}/>
        </button>
      </div>
      <div style={{ position: 'absolute', bottom: 22, left: 0, right: 0, display: 'flex', justifyContent: 'center', zIndex: 3 }}>
        <span className="mono" style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>Tap to stop</span>
      </div>
      <HomeIndicator dark={true}/>
    </div>
  );
}

function Stat({ label, value, color = 'white' }) {
  return (
    <div>
      <div className="mono" style={{ fontSize: 9, color: 'rgba(255,255,255,0.5)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>{label}</div>
      <div className="mono" style={{ fontSize: 13, color, fontWeight: 600, marginTop: 2 }}>{value}</div>
    </div>
  );
}

// Submit Success — three lines, fade in/out, one at a time
function SubmitSuccessScreen({ onDone, points = 580 }) {
  const lines = [
    'Data is uploading and will be under review.',
    'Please keep internet connection.',
    'Points will be credited within approximately 48 hours.',
  ];
  const [idx, setIdx] = React.useState(0);

  React.useEffect(() => {
    const cycle = setInterval(() => setIdx(i => (i + 1) % lines.length), 2400);
    return () => { clearInterval(cycle); };
  }, []);

  const confetti = Array.from({ length: 26 }).map((_, i) => ({
    x: Math.random() * 100,
    delay: Math.random() * 0.8,
    dur: 2 + Math.random() * 1.5,
    size: 4 + Math.random() * 6,
    color: ['#14C9A8', '#FFD60A', '#45E0BA', '#FAFAF7'][i % 4],
  }));

  return (
    <div className="dg-screen" style={{ alignItems: 'center', justifyContent: 'center' }}>
      <TopStatus />
      <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none' }}>
        {confetti.map((c, i) => (
          <div key={i} style={{
            position: 'absolute', left: `${c.x}%`, bottom: -20,
            width: c.size, height: c.size, background: c.color, borderRadius: 2,
            animation: `confettiFloat ${c.dur}s ${c.delay}s ease-out forwards`,
          }}/>
        ))}
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 32, textAlign: 'center', zIndex: 1 }}>
        <div style={{
          width: 120, height: 120, borderRadius: '50%',
          background: 'var(--accent)', color: 'white',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          marginBottom: 28, animation: 'scaleIn .5s',
          boxShadow: '0 12px 60px var(--accent-glow)',
        }}>
          <Icon.Check size={64}/>
        </div>
        <h1 style={{ fontSize: 32, fontWeight: 700, letterSpacing: '-0.03em', margin: '0 0 28px', animation: 'fadeUp .5s .2s backwards' }}>
          Submitted!
        </h1>

        {/* fade-rotating lines — fixed height so layout doesn't jump */}
        <div style={{ height: 72, display: 'flex', alignItems: 'center', justifyContent: 'center', maxWidth: 290, marginBottom: 24 }}>
          {lines.map((line, i) => (
            <div key={i} style={{
              position: 'absolute',
              fontSize: 15, lineHeight: 1.5, color: 'var(--text)',
              maxWidth: 300, padding: '0 20px',
              opacity: idx === i ? 1 : 0,
              transform: idx === i ? 'translateY(0)' : 'translateY(6px)',
              transition: 'opacity .55s ease, transform .55s ease',
              pointerEvents: 'none',
            }}>{line}</div>
          ))}
        </div>

        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '10px 18px',
          background: 'var(--surface)', border: '1px solid var(--border)',
          borderRadius: 999, animation: 'fadeUp .5s .4s backwards',
          marginBottom: 24,
        }}>
          <Icon.Bolt size={16}/>
          <span className="mono" style={{ fontSize: 16, fontWeight: 600, color: 'var(--accent)' }}>+{points}</span>
          <span style={{ fontSize: 13, color: 'var(--text-dim)' }}>pending review</span>
        </div>

        <button
          onClick={() => onDone?.()}
          className="cta"
          style={{
            maxWidth: 280,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            animation: 'fadeUp .5s .55s backwards',
          }}
        >
          Go To Submissions
          <Icon.ChevronRight size={20}/>
        </button>
      </div>

      <div style={{ display: 'flex', gap: 6, justifyContent: 'center', paddingBottom: 28, zIndex: 1 }}>
        {lines.map((_, i) => (
          <div key={i} style={{
            width: idx === i ? 18 : 5, height: 5, borderRadius: 3,
            background: idx === i ? 'var(--accent)' : 'var(--border-strong)',
            transition: 'all .4s ease',
          }}/>
        ))}
      </div>
      <HomeIndicator />
    </div>
  );
}

Object.assign(window, { TaskDetailScreen, RecordingScreen, SubmitSuccessScreen });
