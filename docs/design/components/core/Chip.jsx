import React from 'react';
export function Chip({active,selected,icon,children,onClick,style}){
  const on=active||selected;
  const [pressed,setPressed]=React.useState(false);
  return <button onClick={onClick} onPointerDown={()=>setPressed(true)} onPointerUp={()=>setPressed(false)} onPointerLeave={()=>setPressed(false)} style={{display:'inline-flex',alignItems:'center',gap:6,padding:'8px 16px',borderRadius:'var(--radius-pill)',fontSize:13,fontWeight:600,fontFamily:'var(--font-latin)',cursor:'pointer',border:on?'1px solid transparent':'1px solid var(--line)',background:on?'var(--terracotta)':'transparent',color:on?'#fff':'var(--text-soft)',transform:pressed?'scale(.95)':'none',transition:'transform .12s ease,background .15s ease,color .15s ease',...style}}>{icon}{children}</button>;
}
