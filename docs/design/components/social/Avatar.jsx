import React from 'react';
export function Avatar({name='',src,size=36,style}){
  const initials=name.split(' ').map(w=>w[0]).filter(Boolean).slice(0,2).join('').toUpperCase();
  return <span style={{width:size,height:size,borderRadius:'50%',overflow:'hidden',display:'inline-flex',alignItems:'center',justifyContent:'center',background:'var(--terracotta-tint)',color:'var(--terracotta-dark)',fontWeight:700,fontSize:Math.round(size*.36),fontFamily:'var(--font-latin)',flexShrink:0,boxSizing:'border-box',...style}}>{src?<img src={src} alt={name} style={{width:'100%',height:'100%',objectFit:'cover'}}/>:initials}</span>;
}