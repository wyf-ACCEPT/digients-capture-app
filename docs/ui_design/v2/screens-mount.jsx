// screens-mount.jsx — Mount instruction (between Task Detail and Recording)
//
// Two sequential lines, each fades in → holds → fades out.
// Line 1: phone illustration with arrow showing the camera-up side.
// Line 2: headband illustration.
// On the last fade-out, calls onDone() to advance to recording.

const MOUNT_STEPS = [
  {
    text: 'Place your phone horizontally with arrow pointing upward',
    Illustration: PhoneArrowIllustration,
  },
  {
    text: 'Mount on headband for data collection',
    Illustration: HeadbandIllustration,
  },
];

function MountInstructionScreen({ onDone }) {
  const [stepIdx, setStepIdx] = React.useState(0);
  const [visible, setVisible] = React.useState(false);

  React.useEffect(() => {
    // sequence per step: fade in (250ms) → hold (1900ms) → fade out (450ms) → next
    const inT = setTimeout(() => setVisible(true), 80);
    const outT = setTimeout(() => setVisible(false), 80 + 250 + 1900);
    const nextT = setTimeout(() => {
      if (stepIdx < MOUNT_STEPS.length - 1) {
        setStepIdx(stepIdx + 1);
      } else {
        onDone?.();
      }
    }, 80 + 250 + 1900 + 450);
    return () => { clearTimeout(inT); clearTimeout(outT); clearTimeout(nextT); };
  }, [stepIdx]);

  const Step = MOUNT_STEPS[stepIdx];
  const Illustration = Step.Illustration;

  return (
    <div className="dg-screen" style={{ background: '#000' }}>
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(circle at 50% 45%, rgba(28,28,32,1) 0%, rgba(8,8,10,1) 100%)' }}/>
      <TopStatus dark={true}/>

      {/* skip — small, in corner */}
      <button
        onClick={() => onDone?.()}
        style={{
          position: 'absolute', top: 56, right: 20, zIndex: 4,
          background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.12)',
          color: 'rgba(255,255,255,0.7)', padding: '6px 12px', borderRadius: 999,
          fontSize: 12, fontFamily: 'JetBrains Mono', letterSpacing: '0.05em',
          cursor: 'pointer',
        }}
      >Skip</button>

      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        padding: '0 32px',
        zIndex: 2, position: 'relative',
      }}>
        <div style={{
          opacity: visible ? 1 : 0,
          transform: visible ? 'translateY(0) scale(1)' : 'translateY(8px) scale(0.97)',
          transition: 'opacity .45s ease, transform .45s ease',
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          gap: 40,
          width: '100%',
        }}>
          <div style={{ height: 240, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Illustration />
          </div>
          <div style={{
            color: 'white',
            fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em',
            lineHeight: 1.35, textAlign: 'center', textWrap: 'balance',
            maxWidth: 320,
          }}>
            {Step.text}
          </div>
        </div>
      </div>

      {/* progress dots */}
      <div style={{ display: 'flex', gap: 6, justifyContent: 'center', paddingBottom: 36, zIndex: 2 }}>
        {MOUNT_STEPS.map((_, i) => (
          <div key={i} style={{
            width: i === stepIdx ? 18 : 5, height: 5, borderRadius: 3,
            background: i === stepIdx ? 'white' : 'rgba(255,255,255,0.2)',
            transition: 'all .4s ease',
          }}/>
        ))}
      </div>
      <HomeIndicator dark={true}/>
    </div>
  );
}

// Phone shown landscape (horizontal) with a vertical arrow pointing up to its top edge.
// "Arrow pointing upward" = the side of the phone that should face up (the camera/long edge).
function PhoneArrowIllustration() {
  return (
    <svg width="280" height="220" viewBox="0 0 280 220" fill="none">
      {/* up arrow above phone */}
      <g style={{ animation: 'arrowFloat 1.6s ease-in-out infinite' }}>
        <line x1="140" y1="20" x2="140" y2="62" strokeWidth="2.5" strokeLinecap="round" style={{ stroke: 'var(--accent)' }}/>
        <path d="M130 32 L140 20 L150 32" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{ stroke: 'var(--accent)', fill: 'none' }}/>
      </g>
      {/* "this side up" label */}
      <text x="170" y="42" fontSize="10" fontFamily="JetBrains Mono" fill="rgba(255,255,255,0.55)" letterSpacing="0.1em">THIS SIDE UP</text>

      {/* phone in landscape */}
      <g transform="translate(40, 80)">
        {/* body */}
        <rect x="0" y="0" width="200" height="100" rx="14" ry="14" fill="#1c1c20" stroke="rgba(255,255,255,0.18)" strokeWidth="1.5"/>
        {/* screen */}
        <rect x="6" y="6" width="188" height="88" rx="10" ry="10" fill="#0a0a0a"/>
        {/* dynamic island / front cam (centered along the long edge that faces up) */}
        <rect x="92" y="10" width="36" height="9" rx="4.5" ry="4.5" fill="#000" stroke="rgba(255,255,255,0.2)" strokeWidth="0.5"/>
        {/* rear camera bump on left short edge — landscape orientation */}
        <g transform="translate(14, 30)">
          <rect x="0" y="0" width="28" height="40" rx="6" ry="6" fill="#0a0a0a" stroke="rgba(255,255,255,0.15)" strokeWidth="0.8"/>
          <circle cx="14" cy="13" r="6" fill="#1c1c20" stroke="rgba(255,255,255,0.3)" strokeWidth="0.8"/>
          <circle cx="14" cy="13" r="3.5" style={{ fill: 'var(--accent)', fillOpacity: 0.3 }}/>
          <circle cx="14" cy="28" r="4" fill="#1c1c20" stroke="rgba(255,255,255,0.3)" strokeWidth="0.8"/>
        </g>
      </g>

      {/* gravity / orientation hint */}
      <g transform="translate(20, 195)" opacity="0.4">
        <line x1="0" y1="0" x2="240" y2="0" stroke="white" strokeWidth="0.5" strokeDasharray="3 3"/>
      </g>
    </svg>
  );
}

// Headband strap with phone mount on the front
function HeadbandIllustration() {
  return (
    <svg width="280" height="220" viewBox="0 0 280 220" fill="none">
      {/* head silhouette (simplified) */}
      <ellipse cx="140" cy="135" rx="62" ry="74" fill="#1c1c20" stroke="rgba(255,255,255,0.18)" strokeWidth="1.5"/>
      {/* ear */}
      <ellipse cx="78" cy="138" rx="8" ry="14" fill="#1c1c20" stroke="rgba(255,255,255,0.18)" strokeWidth="1.5"/>

      {/* headband strap going around the head — thick band */}
      <path d="M 78 110 Q 140 85 202 110" stroke="rgba(255,255,255,0.7)" strokeWidth="14" strokeLinecap="round" fill="none"/>
      <path d="M 78 110 Q 140 85 202 110" stroke="rgba(255,255,255,0.95)" strokeWidth="2" fill="none"/>
      {/* texture stitching */}
      <path d="M 90 102 Q 140 81 190 102" stroke="rgba(0,0,0,0.3)" strokeWidth="0.5" strokeDasharray="3 2" fill="none"/>

      {/* phone mounted on forehead in landscape */}
      <g transform="translate(102, 75)">
        <rect x="0" y="0" width="76" height="38" rx="6" ry="6" fill="#0a0a0a" strokeWidth="1.5" style={{ stroke: 'var(--accent)' }}/>
        <rect x="3" y="3" width="70" height="32" rx="4" ry="4" fill="#0d0d10"/>
        {/* camera bump */}
        <g transform="translate(8, 10)">
          <rect x="0" y="0" width="14" height="18" rx="3" ry="3" fill="#1c1c20" stroke="rgba(255,255,255,0.2)" strokeWidth="0.5"/>
          <circle cx="7" cy="6" r="3" fill="#0a0a0a" stroke="rgba(255,255,255,0.4)" strokeWidth="0.5"/>
          <circle cx="7" cy="6" r="1.5" style={{ fill: 'var(--accent)' }}/>
        </g>
        {/* recording indicator */}
        <circle cx="62" cy="8" r="2" style={{ fill: 'var(--accent)' }}>
          <animate attributeName="opacity" values="1;0.3;1" dur="1.5s" repeatCount="indefinite"/>
        </circle>
      </g>

      {/* eyes peek (subtle) */}
      <ellipse cx="118" cy="140" rx="5" ry="3" fill="rgba(255,255,255,0.08)"/>
      <ellipse cx="162" cy="140" rx="5" ry="3" fill="rgba(255,255,255,0.08)"/>
    </svg>
  );
}

Object.assign(window, { MountInstructionScreen });
