import React from 'react';
import {Icon} from '../core/Icon';
// Dining trail — past visits as a connected string of lantern-dot nodes, not a flat photo grid.
// SAHRA's product is connected memories, not isolated bookings; the trail makes that literal.
export function DiningTrail({visits=[],style}){
  return <div style={{position:'relative',fontFamily:'var(--font-latin)',...style}}>
    {visits.map((v,i)=>{const last=i===visits.length-1;const glow=i===0;
      return <div key={i} style={{display:'flex',gap:16,paddingBottom:last?0:22,position:'relative'}}>
        <div style={{position:'relative',display:'flex',flexDirection:'column',alignItems:'center'}}>
          {!last&&<span style={{position:'absolute',top:26,bottom:-22,width:2,background:'linear-gradient(var(--line),transparent)'}}></span>}
          <span style={{width:26,height:26,borderRadius:'50%',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,color:glow?'#121212':'var(--gold)',background:glow?'var(--gold)':'transparent',border:glow?'none':'1.5px solid var(--line)',boxShadow:glow?'0 0 18px rgba(224,169,109,.55)':'none',position:'relative',zIndex:1}}><Icon name="lantern" size={16}/></span>
        </div>
        <div style={{flex:1,paddingTop:2}}>
          <div style={{fontFamily:'var(--font-display)',fontSize:17,fontWeight:600,letterSpacing:'-.01em',color:'var(--text-body)'}}>{v.name}</div>
          <div style={{fontSize:12,color:'var(--text-faint)',marginTop:2}}>{v.date}{v.note?' · '+v.note:''}</div>
        </div>
      </div>;})}
  </div>;
}
