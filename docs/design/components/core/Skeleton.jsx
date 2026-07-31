import React from 'react';
import {mashrabiyaUrl} from '../brand/Mashrabiya';
// Loading placeholder with the signature mashrabiya shimmer — the lattice glints as light sweeps across.
export function Skeleton({width='100%',height=16,radius='var(--radius-md)',lattice=false,style}){
  return <div style={{position:'relative',width,height,borderRadius:radius,background:'var(--surface-sunken)',overflow:'hidden',...style}}>
    <style>{`@keyframes sahraShimmer{0%{transform:translateX(-100%)}100%{transform:translateX(100%)}}`}</style>
    {lattice&&<div style={{position:'absolute',inset:0,backgroundImage:mashrabiyaUrl('currentColor',36),color:'var(--text-body)',opacity:.05}}></div>}
    <div style={{position:'absolute',inset:0,background:'linear-gradient(100deg,transparent 30%,rgba(224,169,109,.16) 50%,transparent 70%)',animation:'sahraShimmer 1.6s ease-in-out infinite'}}></div>
  </div>;
}
export function SkeletonCard({style}){
  return <div style={{width:250,border:'1px solid var(--line)',borderRadius:'var(--radius-lg)',overflow:'hidden',background:'var(--surface-card)',...style}}>
    <Skeleton height={140} radius={0} lattice/>
    <div style={{padding:14,display:'flex',flexDirection:'column',gap:10}}>
      <Skeleton width="70%" height={18}/>
      <Skeleton width="45%" height={12}/>
      <Skeleton width="85%" height={12}/>
    </div>
  </div>;
}
