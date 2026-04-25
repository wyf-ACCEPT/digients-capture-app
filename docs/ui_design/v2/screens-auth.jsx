// screens-auth.jsx — Auth (login + register) placeholder
// V2 stub: any input (or empty) → onAuth() lands on Home.
// V3 backend wires: phone OTP / email OTP / OAuth.

function AuthScreen({ onAuth }) {
  const [mode, setMode] = React.useState('login'); // 'login' | 'register'
  const [method, setMethod] = React.useState('phone'); // 'phone' | 'email'
  const [identifier, setIdentifier] = React.useState('');
  const [otp, setOtp] = React.useState('');
  const [otpSent, setOtpSent] = React.useState(false);

  const submit = (e) => {
    e?.preventDefault?.();
    onAuth?.();
  };

  return (
    <div className="dg-screen" style={{ background: 'var(--bg)' }}>
      <TopStatus />

      {/* Hero block */}
      <div style={{ flex: '0 0 auto', padding: '36px 28px 24px' }}>
        <div style={{
          width: 56, height: 56, borderRadius: 16,
          background: 'linear-gradient(135deg, var(--accent), color-mix(in oklch, var(--accent) 50%, #6366f1))',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 8px 32px color-mix(in oklch, var(--accent) 35%, transparent)',
          marginBottom: 22,
        }}>
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="3.5"/>
            <path d="M3 8a2 2 0 0 1 2-2h2l2-2h6l2 2h2a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8z"/>
          </svg>
        </div>
        <h1 style={{ fontSize: 30, fontWeight: 700, letterSpacing: '-0.025em', margin: 0, lineHeight: 1.15 }}>
          {mode === 'login' ? 'Welcome back' : 'Create account'}
        </h1>
        <div style={{ fontSize: 15, color: 'var(--text-dim)', marginTop: 8, lineHeight: 1.45 }}>
          {mode === 'login'
            ? 'Sign in to keep capturing and earning points.'
            : 'Join thousands of contributors building better robots.'}
        </div>
      </div>

      <form onSubmit={submit} style={{ flex: 1, padding: '8px 28px 24px', display: 'flex', flexDirection: 'column', overflow: 'auto' }}>

        {/* method tabs */}
        <div style={{ display: 'flex', gap: 6, padding: 4, background: 'var(--surface-2)', borderRadius: 12, marginBottom: 18 }}>
          {[
            { k: 'phone', label: 'Phone' },
            { k: 'email', label: 'Email' },
          ].map(m => (
            <button
              key={m.k} type="button"
              onClick={() => { setMethod(m.k); setOtpSent(false); setIdentifier(''); }}
              style={{
                flex: 1, padding: '9px 0', borderRadius: 8, border: 'none', cursor: 'pointer',
                background: method === m.k ? 'var(--surface)' : 'transparent',
                color: method === m.k ? 'var(--text)' : 'var(--text-dim)',
                fontWeight: 500, fontSize: 13, letterSpacing: '-0.01em',
                transition: 'all 0.15s ease',
              }}
            >{m.label}</button>
          ))}
        </div>

        {/* identifier field */}
        <label style={{ display: 'block', marginBottom: 14 }}>
          <div className="mono" style={{ fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--text-dim)', marginBottom: 8 }}>
            {method === 'phone' ? 'Phone Number' : 'Email Address'}
          </div>
          <input
            type={method === 'phone' ? 'tel' : 'email'}
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
            placeholder={method === 'phone' ? '+1 (415) 555 0100' : 'you@example.com'}
            style={{
              width: '100%', boxSizing: 'border-box',
              background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12,
              padding: '14px 16px', color: 'var(--text)', fontSize: 16, fontWeight: 500,
              outline: 'none', letterSpacing: '-0.01em',
              transition: 'border-color 0.15s ease',
            }}
            onFocus={(e) => e.target.style.borderColor = 'var(--accent)'}
            onBlur={(e) => e.target.style.borderColor = 'var(--border)'}
          />
        </label>

        {/* OTP field — appears after "Send code" */}
        {otpSent && (
          <label style={{ display: 'block', marginBottom: 14, animation: 'fadeUp .35s' }}>
            <div className="mono" style={{ fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--text-dim)', marginBottom: 8, display: 'flex', justifyContent: 'space-between' }}>
              <span>Verification Code</span>
              <span style={{ color: 'var(--accent)' }}>Sent · 0:58</span>
            </div>
            <input
              type="text" inputMode="numeric" maxLength={6}
              value={otp}
              onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
              placeholder="6-digit code"
              className="mono"
              style={{
                width: '100%', boxSizing: 'border-box',
                background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 12,
                padding: '14px 16px', color: 'var(--text)', fontSize: 18, fontWeight: 500,
                outline: 'none', letterSpacing: '0.5em',
                transition: 'border-color 0.15s ease',
              }}
              onFocus={(e) => e.target.style.borderColor = 'var(--accent)'}
              onBlur={(e) => e.target.style.borderColor = 'var(--border)'}
            />
          </label>
        )}

        {/* Register: terms */}
        {mode === 'register' && (
          <div style={{ fontSize: 12, color: 'var(--text-dim)', lineHeight: 1.5, marginTop: 4, marginBottom: 14 }}>
            By creating an account you agree to our{' '}
            <span style={{ color: 'var(--accent)', textDecoration: 'underline' }}>Terms</span> and{' '}
            <span style={{ color: 'var(--accent)', textDecoration: 'underline' }}>Privacy Policy</span>.
            Recording uploads are reviewed by humans.
          </div>
        )}

        <div style={{ flex: 1 }}/>

        {/* Primary CTA */}
        {!otpSent ? (
          <button
            type="button"
            onClick={() => setOtpSent(true)}
            className="cta"
            style={{ marginTop: 8 }}
          >
            Send verification code
          </button>
        ) : (
          <button type="submit" className="cta" style={{ marginTop: 8 }}>
            {mode === 'login' ? 'Sign in' : 'Create account'}
          </button>
        )}

        {/* Divider */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '20px 0 14px' }}>
          <div style={{ flex: 1, height: 1, background: 'var(--border)' }}/>
          <div className="mono" style={{ fontSize: 10, color: 'var(--text-faint)', letterSpacing: '0.16em', textTransform: 'uppercase' }}>or</div>
          <div style={{ flex: 1, height: 1, background: 'var(--border)' }}/>
        </div>

        {/* OAuth */}
        <div style={{ display: 'flex', gap: 10 }}>
          <SocialBtn onClick={submit} kind="apple"/>
          <SocialBtn onClick={submit} kind="google"/>
        </div>

        {/* Switch mode */}
        <div style={{ textAlign: 'center', marginTop: 22, fontSize: 14, color: 'var(--text-dim)' }}>
          {mode === 'login' ? "Don't have an account? " : 'Already have an account? '}
          <span
            onClick={() => { setMode(mode === 'login' ? 'register' : 'login'); setOtpSent(false); setOtp(''); }}
            style={{ color: 'var(--accent)', fontWeight: 600, cursor: 'pointer' }}
          >{mode === 'login' ? 'Register' : 'Sign in'}</span>
        </div>
      </form>

      <HomeIndicator />
    </div>
  );
}

function SocialBtn({ kind, onClick }) {
  const isApple = kind === 'apple';
  return (
    <button
      type="button" onClick={onClick}
      className="tap"
      style={{
        flex: 1, padding: '13px 0', borderRadius: 12,
        background: 'var(--surface)', border: '1px solid var(--border)',
        color: 'var(--text)', cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        fontSize: 14, fontWeight: 500,
      }}
    >
      {isApple ? (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
          <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
        </svg>
      ) : (
        <svg width="18" height="18" viewBox="0 0 24 24">
          <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
          <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
          <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
          <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
        </svg>
      )}
      {isApple ? 'Apple' : 'Google'}
    </button>
  );
}

Object.assign(window, { AuthScreen });
