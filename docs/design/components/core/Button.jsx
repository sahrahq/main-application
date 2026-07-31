import React from 'react';
const padMap={sm:'8px 14px',md:'12px 20px',lg:'15px 26px'};
const fsMap={sm:13,md:14,lg:15};
export function Button({variant='primary',size='md',pill,disabled,icon,children,style,...rest}){
  const [pressed,setPressed]=React.useState(false);
  const [hover,setHover]=React.useState(false);
  const variants={
    primary:{background:hover?'var(--terracotta-dark)':'var(--terracotta)',color:'#fff',border:'none'},
    secondary:{background:hover?'var(--terracotta-tint)':'transparent',color:'var(--terracotta)',border:'1.5px solid var(--terracotta)'},
    ghost:{background:hover?'var(--surface-sunken)':'transparent',color:'var(--text-body)',border:'none'},
    gold:{background:hover?'var(--gold-dark)':'var(--gold)',color:'#121212',border:'none'}
  };
  const dis=disabled?{background:'var(--border)',color:'var(--ink-faint)',border:'none'}:{};
  return <button disabled={disabled}
    onMouseEnter={()=>setHover(true)} onMouseLeave={()=>{setHover(false);setPressed(false)}}
    onMouseDown={()=>setPressed(true)} onMouseUp={()=>setPressed(false)}
    style={{fontFamily:'var(--font-latin)',fontWeight:600,fontSize:fsMap[size],borderRadius:pill?'var(--radius-pill)':'var(--radius-md)',padding:padMap[size],cursor:disabled?'not-allowed':'pointer',display:'inline-flex',alignItems:'center',justifyContent:'center',gap:8,transition:'transform .05s ease,background .15s ease',transform:pressed?'scale(.98)':'none',...variants[variant],...dis,...style}} {...rest}>{icon}{children}</button>;
}
