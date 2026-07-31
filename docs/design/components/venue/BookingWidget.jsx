import React from 'react';
import {Button} from '../core/Button';
import {Chip} from '../core/Chip';
import {Icon} from '../core/Icon';
export function BookingWidget({venue='Layali Lounge',times=['7:30 PM','9:00 PM','10:30 PM'],defaultTime,defaultParty=2,onBook,width=320,style}){
  const [party,setParty]=React.useState(defaultParty);
  const [time,setTime]=React.useState(defaultTime||times[1]);
  const [booked,setBooked]=React.useState(false);
  const step=d=>setParty(p=>Math.max(1,Math.min(12,p+d)));
  const stepBtn={width:32,height:32,borderRadius:'50%',border:'1px solid var(--line)',background:'var(--surface-card)',color:'var(--text-body)',fontSize:16,cursor:'pointer',fontFamily:'var(--font-latin)',lineHeight:1};
  return <div style={{width,background:'var(--surface-card)',border:'1px solid var(--line)',borderRadius:'var(--radius-lg)',boxShadow:'var(--shadow-2)',padding:20,fontFamily:'var(--font-latin)',boxSizing:'border-box',...style}}>
    {booked?<div style={{textAlign:'center',padding:'8px 0',display:'flex',flexDirection:'column',alignItems:'center',gap:8}}>
      <span style={{color:'var(--success)'}}><Icon name="circle-check" size={32}/></span>
      <div style={{fontSize:17,fontWeight:700,color:'var(--text-body)'}}>You&rsquo;re in.</div>
      <div style={{fontSize:13,color:'var(--text-soft)',lineHeight:1.5}}>Your table for {party} is set for {time} at {venue}. We told them you&rsquo;re coming.</div>
      <Button variant="ghost" size="sm" onClick={()=>setBooked(false)}>Change plans</Button>
    </div>:<div>
      <div style={{fontSize:11,fontWeight:700,letterSpacing:'var(--tracking-overline)',textTransform:'uppercase',color:'var(--terracotta)',marginBottom:12}}>Tonight · {venue}</div>
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:14}}>
        <span style={{fontSize:13,fontWeight:600,color:'var(--text-body)'}}>Party size</span>
        <span style={{display:'inline-flex',alignItems:'center',gap:12}}>
          <button style={stepBtn} onClick={()=>step(-1)}>&minus;</button>
          <span style={{fontSize:15,fontWeight:700,minWidth:16,textAlign:'center',color:'var(--text-body)'}}>{party}</span>
          <button style={stepBtn} onClick={()=>step(1)}>+</button>
        </span>
      </div>
      <div style={{display:'flex',gap:8,flexWrap:'wrap',marginBottom:16}}>{times.map(t=><Chip key={t} active={t===time} onClick={()=>setTime(t)}>{t}</Chip>)}</div>
      <Button style={{width:'100%'}} onClick={()=>{setBooked(true);onBook&&onBook({party,time})}}>Book this table</Button>
      <div style={{fontSize:12,color:'var(--text-faint)',textAlign:'center',marginTop:10}}>Free cancellation up to 2 hours before.</div>
    </div>}
  </div>;
}