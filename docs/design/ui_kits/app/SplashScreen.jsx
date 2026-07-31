import React from 'react';
import {Mashrabiya} from '../../components/brand/Mashrabiya';
// App-launch splash. Theme-aware: night surface + cream mark in dark mode, warm cream surface +
// terracotta mark in light mode. Motion: crisp mark settle → wordmark tracks in → gold hairline
// draws → quick fade handoff. No blur/glow shadows.
export function SplashScreen({onDone,lang='en',dark=true,logoSrc,duration=2000}){
  const ar=lang==='ar';
  const src=logoSrc||(dark?'../../assets/logo.png':'../../assets/logo-terracotta.png');
  const [leaving,setLeaving]=React.useState(false);
  React.useEffect(()=>{
    const t1=setTimeout(()=>setLeaving(true),duration);
    const t2=setTimeout(()=>onDone&&onDone(),duration+380);
    return()=>{clearTimeout(t1);clearTimeout(t2)};
  },[duration,onDone]);
  return <div className={dark?'theme-night':''} style={{position:'absolute',inset:0,background:dark?'var(--night)':'var(--cream)',overflow:'hidden',display:'flex',alignItems:'center',justifyContent:'center',opacity:leaving?0:1,transition:'opacity .38s ease',zIndex:50}}>
    <style>{`
      @keyframes sahraMark{0%{opacity:0;transform:translateY(8px) scale(.92)}100%{opacity:1;transform:none}}
      @keyframes sahraWord{0%{opacity:0;letter-spacing:.55em}100%{opacity:1;letter-spacing:.32em}}
      @keyframes sahraLine{0%{transform:scaleX(0)}100%{transform:scaleX(1)}}
      @keyframes sahraLattice{0%{opacity:0}100%{opacity:1}}
      @keyframes sahraSub{0%{opacity:0;transform:translateY(6px)}100%{opacity:1;transform:none}}
    `}</style>
    <div style={{position:'absolute',inset:0,animation:'sahraLattice 1.6s .6s ease both'}}>
      <Mashrabiya color={dark?'var(--gold)':'var(--terracotta)'} opacity={dark?0.05:0.04} tile={52} fade/>
    </div>
    <div style={{position:'relative',display:'flex',flexDirection:'column',alignItems:'center',gap:20}}>
      <img src={src} alt="SAHRA" style={{width:92,animation:'sahraMark .7s .1s cubic-bezier(.2,.7,.2,1) both'}}/>
      <div style={{fontFamily:'var(--font-display)',fontWeight:600,fontSize:20,letterSpacing:'.32em',color:dark?'var(--night-text)':'var(--terracotta-dark)',animation:'sahraWord .8s .55s cubic-bezier(.2,.7,.2,1) both',paddingInlineStart:'.32em'}}>SAHRA</div>
      <div aria-hidden="true" style={{width:44,height:2,background:dark?'var(--gold)':'var(--gold-dark)',transformOrigin:'center',animation:'sahraLine .5s .95s cubic-bezier(.2,.7,.2,1) both'}}></div>
      {ar&&<div style={{fontFamily:'var(--font-arabic-display)',fontSize:14,color:dark?'var(--night-text-faint)':'var(--text-faint)',animation:'sahraSub .5s 1.15s ease both'}}>سهرة</div>}
    </div>
  </div>;
}
