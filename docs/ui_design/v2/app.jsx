// app.jsx — main entry: design canvas with all screens + click-through prototype

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "dark"
}/*EDITMODE-END*/;

// ───────── click-through prototype ─────────
function Prototype() {
  const [route, setRoute] = React.useState({ name: 'auth', task: null });
  const onNav = (k) => {
    if (k === 'home') setRoute({ name: 'home' });
    if (k === 'tasks') setRoute({ name: 'pool', cat: 'household' });
    if (k === 'files') setRoute({ name: 'files' });
    if (k === 'me') setRoute({ name: 'profile' });
  };
  switch (route.name) {
    case 'auth':
      return <AuthScreen onAuth={() => setRoute({ name: 'home' })}/>;
    case 'home':
      return <HomeScreen onNav={onNav} onCategory={(id) => setRoute({ name: 'pool', cat: id })}/>;
    case 'pool':
      return <TaskPoolScreen category={route.cat} onBack={() => setRoute({ name: 'home' })} onTask={(t) => setRoute({ name: 'detail', task: t })}/>;
    case 'detail':
      return <TaskDetailScreen task={route.task} onBack={() => setRoute({ name: 'pool', cat: 'household' })} onRecord={() => setRoute({ name: 'mount', task: route.task })}/>;
    case 'mount':
      return <MountInstructionScreen onDone={() => setRoute({ name: 'recording', task: route.task })}/>;
    case 'recording':
      return <RecordingScreen task={route.task} onStop={() => setRoute({ name: 'success', task: route.task })}/>;
    case 'success':
      return <SubmitSuccessScreen points={route.task?.points || 580} onDone={() => setRoute({ name: 'files' })}/>;
    case 'files':
      return <SubmissionsScreen onNav={onNav} onRecording={(r) => setRoute({ name: 'recording-detail', rec: r })}/>;
    case 'recording-detail':
      return <RecordingDetailScreen rec={route.rec} onBack={() => setRoute({ name: 'files' })}/>;
    case 'profile':
      return <ProfileScreen onNav={onNav} onSettings={() => setRoute({ name: 'settings' })}/>;
    case 'settings':
      return <SettingsScreen onBack={() => setRoute({ name: 'profile' })}/>;
    default:
      return <HomeScreen onNav={onNav}/>;
  }
}

// ───────── App: canvas + prototype frame side-by-side ─────────
function App() {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);

  React.useEffect(() => {
    document.documentElement.dataset.theme = tweaks.theme || 'dark';
  }, [tweaks.theme]);

  // wrap each screen in iPhone frame for the canvas
  const Frame = ({ children, label }) => (
    <div data-screen-label={label} style={{ width: 393, height: 852, borderRadius: 56, overflow: 'hidden', background: 'var(--bg)', position: 'relative', boxShadow: '0 0 0 12px #1c1c20, 0 30px 80px rgba(0,0,0,0.45)' }}>
      {children}
    </div>
  );

  return (
    <>
      <DesignCanvas>
        <DCSection id="flow" title="Digients Capture · v2 UI" subtitle="Tap any artboard to focus it. Open the live prototype below for a clickable walkthrough.">
          <DCArtboard id="00-auth" label="00 · Sign In / Register" width={393} height={852}>
            <Frame label="00 Auth"><AuthScreen onAuth={() => {}}/></Frame>
          </DCArtboard>
          <DCArtboard id="01-home" label="01 · Home" width={393} height={852}>
            <Frame label="01 Home"><HomeScreen /></Frame>
          </DCArtboard>
          <DCArtboard id="02-pool" label="02 · Task Pool" width={393} height={852}>
            <Frame label="02 Task Pool"><TaskPoolScreen category="household" /></Frame>
          </DCArtboard>
          <DCArtboard id="03-detail" label="03 · Task Detail" width={393} height={852}>
            <Frame label="03 Task Detail"><TaskDetailScreen /></Frame>
          </DCArtboard>
          <DCArtboard id="04-mount" label="04 · Mount Instructions" width={393} height={852}>
            <Frame label="04 Mount"><MountInstructionScreen onDone={() => {}}/></Frame>
          </DCArtboard>
          <DCArtboard id="05-rec" label="05 · Recording" width={393} height={852}>
            <Frame label="05 Recording"><RecordingScreen onStop={() => {}}/></Frame>
          </DCArtboard>
          <DCArtboard id="06-success" label="06 · Submit Success" width={393} height={852}>
            <Frame label="06 Success"><SubmitSuccessScreen onDone={() => {}}/></Frame>
          </DCArtboard>
          <DCArtboard id="07-subs" label="07 · Submissions" width={393} height={852}>
            <Frame label="07 Submissions"><SubmissionsScreen /></Frame>
          </DCArtboard>
          <DCArtboard id="08-sub-detail" label="08 · Submission Detail" width={393} height={852}>
            <Frame label="08 Submission Detail"><RecordingDetailScreen /></Frame>
          </DCArtboard>
          <DCArtboard id="09-profile" label="09 · Me (Profile)" width={393} height={852}>
            <Frame label="09 Profile"><ProfileScreen /></Frame>
          </DCArtboard>
          <DCArtboard id="10-settings" label="10 · Settings" width={393} height={852}>
            <Frame label="10 Settings"><SettingsScreen /></Frame>
          </DCArtboard>
        </DCSection>

        <DCSection id="proto" title="Live Prototype" subtitle="Fully clickable — start at Home, tap a category, then a task, then Record.">
          <DCArtboard id="prototype" label="Prototype · Tap to walk the full flow" width={393} height={852}>
            <Frame label="Prototype"><Prototype /></Frame>
          </DCArtboard>
        </DCSection>
      </DesignCanvas>

      <TweaksPanel title="Tweaks">
        <TweakSection title="Theme">
          <TweakRadio
            label="Mode"
            value={tweaks.theme}
            onChange={(v) => setTweak('theme', v)}
            options={[{ value: 'dark', label: 'Dark' }, { value: 'light', label: 'Light' }]}
          />
        </TweakSection>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
