// screens-core.jsx — Home, Task Pool

const CATEGORIES = [
  { id: 'household', name: 'Household', kind: 'household', count: 142, span: 'tall', avg: '+320 pts' },
  { id: 'industrial', name: 'Industrial', kind: 'industrial', count: 87, span: 'short', avg: '+580 pts' },
  { id: 'sports', name: 'Sports & Skills', kind: 'sports', count: 64, span: 'tall', avg: '+450 pts' },
  { id: 'daily', name: 'Daily Life', kind: 'daily', count: 211, span: 'short', avg: '+180 pts' },
  { id: 'cooking', name: 'Cooking', kind: 'cooking', count: 38, span: 'short', avg: '+390 pts', soon: true },
  { id: 'mobility', name: 'Mobility', kind: 'mobility', count: 0, span: 'short', soon: true },
];

function HomeScreen({ onNav, onCategory, points = 4280, pending = 1500 }) {
  return (
    <div className="dg-screen">
      <TopStatus />
      <div style={{ padding: '12px 20px 20px', flex: '0 0 auto' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
          <div>
            <div className="mono" style={{ fontSize: 11, color: 'var(--text-dim)', letterSpacing: '0.16em', textTransform: 'uppercase' }}>Welcome back</div>
            <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-0.02em', marginTop: 2 }}>Maya Chen</div>
          </div>
          <div onClick={() => onNav?.('me')} className="tap" style={{
            width: 40, height: 40, borderRadius: '50%',
            background: 'linear-gradient(135deg, #14C9A8, #45E0BA)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'white', fontWeight: 700, fontSize: 14,
          }}>MC</div>
        </div>
        <div onClick={() => onNav?.('me')} className="tap" style={{
          display: 'flex', background: 'var(--surface)', border: '1px solid var(--border)',
          borderRadius: 16, padding: '14px 16px', alignItems: 'center', gap: 14,
        }}>
          <div style={{ flex: 1 }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--text-dim)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>Balance</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 3 }}>
              <span className="mono" style={{ fontSize: 24, fontWeight: 600, letterSpacing: '-0.02em' }}>{points.toLocaleString()}</span>
              <span style={{ fontSize: 12, color: 'var(--text-dim)' }}>pts</span>
            </div>
          </div>
          <div style={{ width: 1, alignSelf: 'stretch', background: 'var(--border)' }}/>
          <div style={{ flex: 1 }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--text-dim)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>Pending</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 3 }}>
              <span className="mono" style={{ fontSize: 24, fontWeight: 600, letterSpacing: '-0.02em', color: 'var(--warning)' }}>{pending.toLocaleString()}</span>
              <span style={{ fontSize: 12, color: 'var(--text-dim)' }}>pts</span>
            </div>
          </div>
        </div>
      </div>
      <div style={{ padding: '4px 20px 12px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, letterSpacing: '-0.01em', margin: 0 }}>Choose a category</h2>
        <span className="mono" style={{ fontSize: 11, color: 'var(--text-dim)' }}>{CATEGORIES.reduce((a,c) => a + c.count, 0)} tasks</span>
      </div>
      <div style={{ flex: 1, overflow: 'auto', padding: '0 20px 20px' }}>
        {/* two-column flex masonry — eliminates CSS grid gap issue when tall/short alternate */}
        <div style={{ display: 'flex', gap: 12 }}>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[CATEGORIES[0], CATEGORIES[2], CATEGORIES[4]].map((c, i) => (
              <CategoryCard key={c.id} cat={c} onClick={() => !c.soon && onCategory?.(c.id)} delay={i * 60}/>
            ))}
          </div>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[CATEGORIES[1], CATEGORIES[3], CATEGORIES[5]].map((c, i) => (
              <CategoryCard key={c.id} cat={c} onClick={() => !c.soon && onCategory?.(c.id)} delay={i * 60 + 30}/>
            ))}
          </div>
        </div>
      </div>
      <TabBar active="home" onNav={onNav}/>
      <HomeIndicator />
    </div>
  );
}

function CategoryCard({ cat, onClick, delay = 0 }) {
  const tall = cat.span === 'tall';
  const height = tall ? 220 : 168;
  return (
    <div className="tap" onClick={onClick} style={{
      background: 'var(--surface)',
      border: '1px solid var(--border)',
      borderRadius: 18,
      height,
      padding: 16,
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      position: 'relative', overflow: 'hidden',
      animation: `fadeUp .5s ${delay}ms backwards`,
      opacity: cat.soon ? 0.6 : 1,
    }}>
      {cat.soon && (
        <div style={{
          position: 'absolute', top: 12, right: 12,
          fontSize: 9, fontFamily: 'JetBrains Mono', letterSpacing: '0.14em',
          color: 'var(--text-dim)', textTransform: 'uppercase',
          padding: '3px 7px', border: '1px solid var(--border-strong)', borderRadius: 4,
        }}>Coming Soon</div>
      )}
      <div style={{ position: 'absolute', right: -16, bottom: -16, opacity: 0.35 }}>
        <CategoryGlyph kind={cat.kind} size={tall ? 140 : 110} color={cat.soon ? 'var(--text-faint)' : 'var(--accent)'}/>
      </div>
      <div style={{ position: 'relative', zIndex: 1 }}>
        <div style={{ fontSize: tall ? 20 : 17, fontWeight: 600, letterSpacing: '-0.02em', textWrap: 'balance' }}>{cat.name}</div>
      </div>
      <div style={{ position: 'relative', zIndex: 1, display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div className="mono" style={{ fontSize: 11, color: 'var(--text-dim)' }}>{cat.count > 0 ? `${cat.count} open` : 'In planning'}</div>
        {cat.avg && !cat.soon && <div className="mono" style={{ fontSize: 11, color: 'var(--accent)' }}>avg {cat.avg}</div>}
      </div>
    </div>
  );
}

const TASKS = {
  household: [
    { id: 't1', title: 'Fold a bath towel into thirds', publisher: 'Lab A · Stanford', points: 320, dur: '3-5 min', slots: '12 left', tag: 'Folding' },
    { id: 't2', title: 'Set the dinner table for two', publisher: 'Embodied Co.', points: 480, dur: '5-7 min', slots: '38 left', tag: 'Tableware' },
    { id: 't3', title: 'Wipe down a kitchen counter', publisher: 'Lab A · Stanford', points: 220, dur: '2-3 min', slots: '6 left', tag: 'Cleaning' },
    { id: 't4', title: 'Sort laundry by color', publisher: 'HomeBots Inc.', points: 380, dur: '4-6 min', slots: '21 left', tag: 'Sorting' },
  ],
  industrial: [
    { id: 'i1', title: 'Twist open a Nongfu Spring bottle cap', publisher: 'Robofactory Lab', points: 580, dur: '1-2 min', slots: '4 left', tag: 'Manipulation' },
    { id: 'i2', title: 'Sort 10 hex bolts by size into bins', publisher: 'PartsAI', points: 720, dur: '5-8 min', slots: '17 left', tag: 'Sorting' },
  ],
};

function TaskPoolScreen({ category = 'household', onBack, onTask }) {
  const [filter, setFilter] = React.useState('All');
  const cat = CATEGORIES.find(c => c.id === category) || CATEGORIES[0];
  const tasks = TASKS[category] || TASKS.household;

  return (
    <div className="dg-screen">
      <TopStatus />
      <NavBar title={cat.name} sub={`${tasks.length} tasks · sorted by reward`} onBack={onBack} right={
        <button style={{ background: 'none', border: 'none', color: 'var(--text)', padding: 6 }}><Icon.Search size={20}/></button>
      }/>
      <div style={{ display: 'flex', gap: 8, padding: '12px 16px', overflow: 'auto', flex: '0 0 auto' }}>
        {['All', 'High Reward', 'Quick (<3 min)', 'Beginner', 'Verified'].map(f => (
          <div key={f} className={`chip ${filter === f ? 'active' : ''}`} onClick={() => setFilter(f)}>{f}</div>
        ))}
      </div>
      <div style={{ flex: 1, overflow: 'auto', padding: '4px 16px 20px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {tasks.map((t, i) => (
          <TaskCard key={t.id} task={t} onClick={() => onTask?.(t)} delay={i * 50}/>
        ))}
      </div>
      <HomeIndicator />
    </div>
  );
}

function TaskCard({ task, onClick, delay = 0 }) {
  return (
    <div className="tap" onClick={onClick} style={{
      background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 18,
      overflow: 'hidden', animation: `fadeUp .5s ${delay}ms backwards`,
    }}>
      <div style={{ position: 'relative' }}>
        <ImagePlaceholder label={task.tag} height={160}/>
        <div style={{ position: 'absolute', top: 12, right: 12 }}>
          <span className="points-pill"><Icon.Bolt size={11}/>+{task.points}</span>
        </div>
        <div style={{ position: 'absolute', top: 12, left: 12 }}>
          <span className="chip" style={{ background: 'rgba(10,10,10,0.7)', color: '#fafaf7', borderColor: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(8px)' }}>{task.tag}</span>
        </div>
      </div>
      <div style={{ padding: '14px 16px 16px' }}>
        <div style={{ fontSize: 16, fontWeight: 600, letterSpacing: '-0.01em', lineHeight: 1.3, marginBottom: 6 }}>{task.title}</div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div className="mono" style={{ fontSize: 11, color: 'var(--text-dim)' }}>{task.publisher}</div>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <span className="mono" style={{ fontSize: 11, color: 'var(--text-dim)', display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <Icon.Clock size={12}/>{task.dur}
            </span>
            <span className="mono" style={{ fontSize: 11, color: 'var(--success)' }}>{task.slots}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { HomeScreen, TaskPoolScreen, CATEGORIES, TASKS });
