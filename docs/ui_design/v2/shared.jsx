// shared.jsx — shared icons and small primitives for Digients Capture

const Icon = {
  Home: ({ size = 24, fill = 'none' }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill === 'filled' ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="1.8">
      <path d="M3 11l9-8 9 8v9a2 2 0 0 1-2 2h-4v-7h-6v7H5a2 2 0 0 1-2-2v-9z" strokeLinejoin="round"/>
    </svg>
  ),
  Tasks: ({ size = 24, fill = 'none' }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <rect x="3" y="4" width="7" height="7" rx="1.5" fill={fill === 'filled' ? 'currentColor' : 'none'}/>
      <rect x="14" y="4" width="7" height="7" rx="1.5"/>
      <rect x="3" y="14" width="7" height="7" rx="1.5"/>
      <rect x="14" y="14" width="7" height="7" rx="1.5" fill={fill === 'filled' ? 'currentColor' : 'none'}/>
    </svg>
  ),
  Folder: ({ size = 24, fill = 'none' }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill === 'filled' ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="1.8">
      <path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7z" strokeLinejoin="round"/>
    </svg>
  ),
  User: ({ size = 24, fill = 'none' }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <circle cx="12" cy="8" r="4" fill={fill === 'filled' ? 'currentColor' : 'none'}/>
      <path d="M4 21c0-4 3.6-7 8-7s8 3 8 7" strokeLinecap="round"/>
    </svg>
  ),
  ChevronLeft: ({ size = 24 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M15 18l-6-6 6-6"/>
    </svg>
  ),
  ChevronRight: ({ size = 24 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 18l6-6-6-6"/>
    </svg>
  ),
  Close: ({ size = 24 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
      <path d="M6 6l12 12M18 6l-12 12"/>
    </svg>
  ),
  Share: ({ size = 22 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3v13M7 8l5-5 5 5"/>
      <path d="M5 14v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5"/>
    </svg>
  ),
  Trash: ({ size = 20 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M6 6l1 14a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-14"/>
    </svg>
  ),
  Upload: ({ size = 18 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 16V5M7.5 9.5L12 5l4.5 4.5"/>
      <path d="M5 17v1.5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V17"/>
    </svg>
  ),
  Clock: ({ size = 16 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>
    </svg>
  ),
  Bolt: ({ size = 14 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M13 2L4 14h7l-1 8 9-12h-7l1-8z"/>
    </svg>
  ),
  Storage: ({ size = 16 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <ellipse cx="12" cy="5" rx="8" ry="2.5"/>
      <path d="M4 5v6c0 1.4 3.6 2.5 8 2.5s8-1.1 8-2.5V5"/>
      <path d="M4 11v6c0 1.4 3.6 2.5 8 2.5s8-1.1 8-2.5v-6"/>
    </svg>
  ),
  Check: ({ size = 24 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 13l4 4L19 7"/>
    </svg>
  ),
  Camera: ({ size = 22 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round">
      <path d="M3 8a2 2 0 0 1 2-2h2l2-2h6l2 2h2a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8z"/>
      <circle cx="12" cy="13" r="4"/>
    </svg>
  ),
  Search: ({ size = 18 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
      <circle cx="11" cy="11" r="7"/><path d="M21 21l-5-5"/>
    </svg>
  ),
  Filter: ({ size = 18 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
      <path d="M4 6h16M7 12h10M10 18h4"/>
    </svg>
  ),
  Settings: ({ size = 22 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3"/>
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h0a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51h0a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v0a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
    </svg>
  ),
  Compass: ({ size = 24 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round">
      <circle cx="12" cy="12" r="9"/>
      <path d="M16.5 7.5l-2.5 6.5-6.5 2.5 2.5-6.5 6.5-2.5z"/>
    </svg>
  ),
  Trophy: ({ size = 18 }) => (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M8 21h8M12 17v4M7 4h10v6a5 5 0 0 1-10 0V4z"/>
      <path d="M17 5h3v3a3 3 0 0 1-3 3M7 5H4v3a3 3 0 0 0 3 3"/>
    </svg>
  ),
};

// category illustration — simple geometric placeholder per category
function CategoryGlyph({ kind, size = 64, color = '#14C9A8' }) {
  const s = size;
  const stroke = { stroke: color, strokeWidth: 1.6, fill: 'none', strokeLinecap: 'round', strokeLinejoin: 'round' };
  if (kind === 'household') {
    return (
      <svg width={s} height={s} viewBox="0 0 64 64" {...stroke}>
        <rect x="14" y="22" width="36" height="22" rx="2"/>
        <path d="M14 30h36M22 22v22M42 22v22"/>
        <path d="M16 18l4-6h24l4 6"/>
      </svg>
    );
  }
  if (kind === 'industrial') {
    return (
      <svg width={s} height={s} viewBox="0 0 64 64" {...stroke}>
        <circle cx="32" cy="32" r="6"/>
        <path d="M32 8v8M32 48v8M8 32h8M48 32h8M15 15l6 6M43 43l6 6M49 15l-6 6M21 43l-6 6"/>
      </svg>
    );
  }
  if (kind === 'sports') {
    return (
      <svg width={s} height={s} viewBox="0 0 64 64" {...stroke}>
        <circle cx="32" cy="32" r="16"/>
        <path d="M16 32c8 0 16 0 16-16M48 32c-8 0-16 0-16 16M32 16c0 8 0 16 16 16M32 48c0-8 0-16-16-16"/>
      </svg>
    );
  }
  if (kind === 'daily') {
    return (
      <svg width={s} height={s} viewBox="0 0 64 64" {...stroke}>
        <rect x="18" y="14" width="28" height="38" rx="2"/>
        <circle cx="40" cy="33" r="1.5" fill={color}/>
        <path d="M18 22h28"/>
      </svg>
    );
  }
  if (kind === 'cooking') {
    return (
      <svg width={s} height={s} viewBox="0 0 64 64" {...stroke}>
        <path d="M16 26h32v12a8 8 0 0 1-8 8H24a8 8 0 0 1-8-8V26z"/>
        <path d="M22 26V18M32 26V14M42 26V18"/>
      </svg>
    );
  }
  // mobility/coming soon
  return (
    <svg width={s} height={s} viewBox="0 0 64 64" {...stroke}>
      <path d="M14 40l8-22h20l8 22"/>
      <circle cx="22" cy="44" r="4"/>
      <circle cx="42" cy="44" r="4"/>
      <path d="M14 40h36"/>
    </svg>
  );
}

// striped image placeholder
function ImagePlaceholder({ label = 'Reference', height = 180, w = '100%' }) {
  return (
    <div className="placeholder-img" style={{ width: w, height, borderRadius: 12 }}>
      {label}
    </div>
  );
}

// status bar (overrides ios-frame's for our dark theme; we re-render time as 9:41)
function TopStatus({ time = '9:41', dark = true }) {
  const c = dark ? '#FAFAF7' : '#0A0A0A';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '14px 24px 6px', height: 44, flex: '0 0 auto',
    }}>
      <span style={{ fontSize: 16, fontWeight: 600, color: c, fontFamily: 'Inter' }}>{time}</span>
      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <svg width="17" height="11" viewBox="0 0 19 12">
          <rect x="0" y="7.5" width="3.2" height="4.5" rx="0.7" fill={c}/>
          <rect x="4.8" y="5" width="3.2" height="7" rx="0.7" fill={c}/>
          <rect x="9.6" y="2.5" width="3.2" height="9.5" rx="0.7" fill={c}/>
          <rect x="14.4" y="0" width="3.2" height="12" rx="0.7" fill={c}/>
        </svg>
        <svg width="15" height="11" viewBox="0 0 17 12">
          <path d="M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z" fill={c}/>
          <path d="M8.5 6.8C9.9 6.8 11.1 7.3 12 8.2L13.1 7.1C11.8 5.9 10.2 5.1 8.5 5.1C6.8 5.1 5.2 5.9 3.9 7.1L5 8.2C5.9 7.3 7.1 6.8 8.5 6.8Z" fill={c}/>
          <circle cx="8.5" cy="10.5" r="1.5" fill={c}/>
        </svg>
        <svg width="24" height="11" viewBox="0 0 27 13">
          <rect x="0.5" y="0.5" width="23" height="12" rx="3.5" stroke={c} strokeOpacity="0.5" fill="none"/>
          <rect x="2" y="2" width="18" height="9" rx="2" fill={c}/>
          <path d="M25 4.5V8.5C25.8 8.2 26.5 7.2 26.5 6.5C26.5 5.8 25.8 4.8 25 4.5Z" fill={c} fillOpacity="0.5"/>
        </svg>
      </div>
    </div>
  );
}

function HomeIndicator({ dark = true }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 8px', flex: '0 0 auto' }}>
      <div style={{ width: 134, height: 5, borderRadius: 3, background: dark ? '#FAFAF7' : '#0A0A0A' }}/>
    </div>
  );
}

function TabBar({ active = 'home', onNav }) {
  const items = [
    { key: 'home',  label: 'Home',        I: Icon.Home },
    { key: 'files', label: 'Submissions', I: Icon.Folder },
    { key: 'me',    label: 'Me',          I: Icon.User },
  ];
  return (
    <div className="tab-bar">
      {items.map(({ key, label, I }) => (
        <div key={key} className={`tab-item ${active === key ? 'active' : ''}`} onClick={() => onNav?.(key)}>
          <I size={24} fill={active === key ? 'filled' : 'none'}/>
          <span>{label}</span>
        </div>
      ))}
    </div>
  );
}

function NavBar({ title, onBack, right = null, sub = null }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', padding: '8px 16px',
      gap: 12, height: 52, flex: '0 0 auto', borderBottom: '1px solid var(--border)',
    }}>
      <button onClick={onBack} style={{
        background: 'none', border: 'none', color: 'var(--text)', cursor: 'pointer',
        padding: 6, marginLeft: -6,
      }}>
        <Icon.ChevronLeft size={26}/>
      </button>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 16, fontWeight: 600, letterSpacing: '-0.01em' }}>{title}</div>
        {sub && <div style={{ fontSize: 12, color: 'var(--text-dim)', marginTop: 2 }}>{sub}</div>}
      </div>
      {right}
    </div>
  );
}

Object.assign(window, { Icon, CategoryGlyph, ImagePlaceholder, TopStatus, HomeIndicator, TabBar, NavBar });
