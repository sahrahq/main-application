import React from 'react';
import {Avatar} from './Avatar';
export function AvatarStack({people=[],max=3,size=32,label,style}){
  const shown=people.slice(0,max);const extra=people.length-shown.length;
  const ring={border:'2px solid var(--surface-page)'};
  return <span style={{display:'inline-flex',alignItems:'center',fontFamily:'var(--font-latin)',...style}}>
    {shown.map((p,i)=><Avatar key={i} name={p.name} src={p.src} size={size} style={{...ring,marginLeft:i?-Math.round(size*.3):0}}/>)}
    {extra>0&&<span style={{width:size,height:size,borderRadius:'50%',background:'var(--surface-sunken)',color:'var(--text-soft)',display:'inline-flex',alignItems:'center',justifyContent:'center',fontSize:11,fontWeight:700,marginLeft:-Math.round(size*.3),boxSizing:'border-box',...ring}}>+{extra}</span>}
    {label&&<span style={{marginLeft:10,fontSize:13,color:'var(--text-soft)'}}>{label}</span>}
  </span>;
}