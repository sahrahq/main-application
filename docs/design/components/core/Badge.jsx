import React from 'react';
export function Badge({variant='neutral',children,style}){
  const v={
    featured:{background:'var(--terracotta)',color:'#fff'},
    gold:{background:'var(--gold)',color:'#121212'},
    success:{background:'rgba(76,122,79,.14)',color:'var(--success)'},
    warning:{background:'rgba(196,138,75,.18)',color:'var(--gold-dark)'},
    error:{background:'rgba(179,65,42,.12)',color:'var(--error)'},
    neutral:{background:'var(--surface-sunken)',color:'var(--text-soft)'}
  }[variant];
  return <span style={{display:'inline-flex',alignItems:'center',gap:6,padding:'4px 10px',borderRadius:'var(--radius-pill)',fontSize:11,fontWeight:700,letterSpacing:'.08em',textTransform:'uppercase',fontFamily:'var(--font-latin)',...v,...style}}>{children}</span>;
}
