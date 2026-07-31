import React from 'react';
import {Button} from '../../components/core/Button';
import {Photo} from './Photo';
const COPY={
  en:[
    {kicker:'Cairo, tonight',title:'Find the vibe for tonight',body:'Rooftops, late-night kitchens, live oud — the city\u2019s best tables, in one place.'},
    {kicker:'No phone calls',title:'Book a table in seconds',body:'Real-time availability. Pick a time, we\u2019ll tell them you\u2019re coming.'},
    {kicker:'For every occasion',title:'From iftar to date night',body:'Curated for Ramadan, birthdays, or just a Tuesday that deserves better.'}
  ],
  ar:[
    {kicker:'\u0627\u0644\u0642\u0627\u0647\u0631\u0629\u060c \u0627\u0644\u0644\u064a\u0644\u0629',title:'\u0627\u0639\u062b\u0631 \u0639\u0644\u0649 \u0623\u062c\u0648\u0627\u0621 \u0644\u064a\u0644\u062a\u0643',body:'\u0631\u0648\u0641 \u062a\u0648\u0628\u060c \u0645\u0637\u0627\u0628\u062e \u062a\u0641\u062a\u062d \u0644\u0648\u0642\u062a \u0645\u062a\u0623\u062e\u0631\u060c \u0648\u0639\u0648\u062f \u062d\u064a \u2014 \u0623\u0641\u0636\u0644 \u0645\u0648\u0627\u0626\u062f \u0627\u0644\u0645\u062f\u064a\u0646\u0629 \u0641\u064a \u0645\u0643\u0627\u0646 \u0648\u0627\u062d\u062f.'},
    {kicker:'\u0645\u0646 \u063a\u064a\u0631 \u0645\u0643\u0627\u0644\u0645\u0627\u062a',title:'\u0627\u062d\u062c\u0632 \u0637\u0627\u0648\u0644\u062a\u0643 \u0641\u064a \u062b\u0648\u0627\u0646\u064d',body:'\u062a\u0648\u0627\u0641\u0631 \u0644\u062d\u0638\u064a. \u0627\u062e\u062a\u0631 \u0627\u0644\u0648\u0642\u062a\u060c \u0648\u0625\u062d\u0646\u0627 \u0646\u0628\u0644\u0651\u063a\u0647\u0645 \u0625\u0646\u0643 \u062c\u0627\u064a.'},
    {kicker:'\u0644\u0643\u0644 \u0645\u0646\u0627\u0633\u0628\u0629',title:'\u0645\u0646 \u0627\u0644\u0625\u0641\u0637\u0627\u0631 \u0644\u0639\u0634\u0627\u0621 \u0631\u0648\u0645\u0627\u0646\u0633\u064a',body:'\u0645\u062e\u062a\u0627\u0631\u0629 \u0644\u0631\u0645\u0636\u0627\u0646\u060c \u0623\u0639\u064a\u0627\u062f \u0627\u0644\u0645\u064a\u0644\u0627\u062f\u060c \u0623\u0648 \u062d\u062a\u0649 \u064a\u0648\u0645 \u062a\u0644\u0627\u062a \u064a\u0633\u062a\u0627\u0647\u0644 \u0623\u062d\u0633\u0646.'}
  ]
};
const UI={en:{next:'Next',start:'Get started',have:'Already with us?',signin:'Sign in'},ar:{next:'\u0627\u0644\u062a\u0627\u0644\u064a',start:'\u0627\u0628\u062f\u0623',have:'\u0639\u0646\u062f\u0643 \u062d\u0633\u0627\u0628\u061f',signin:'\u0633\u062c\u0651\u0644 \u062f\u062e\u0648\u0644'}};
export function Onboarding({onStart,onSignIn,lang='en',dark=true,logoSrc}){
  const src=logoSrc||'../../assets/logo.png'; // hero is always dark — cream mark always
  const [i,setI]=React.useState(0);
  const ar=lang==='ar';
  const slides=COPY[lang]||COPY.en;const s=slides[i];const u=UI[lang]||UI.en;
  // Content sits in a self-contained rounded card (photo on top) — reads well in BOTH themes,
  // unlike a scrim gradient which washed out in light mode. Card follows surface tokens.
  return <div className={dark?'theme-night':''} dir={ar?'rtl':'ltr'} style={{height:'100%',position:'relative',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)',background:'var(--surface-page)',display:'flex',flexDirection:'column'}}>
    <div style={{position:'relative',flex:1,minHeight:0}}>
      <Photo height="100%" style={{position:'absolute',inset:0}}/>
      <div style={{position:'absolute',top:24,insetInlineStart:24}}>
        <img src={src} alt="SAHRA" style={{width:42,filter:'drop-shadow(0 2px 8px rgba(0,0,0,.4))'}}/>
      </div>
    </div>
    <div style={{background:'var(--surface-card)',borderRadius:'24px 24px 0 0',marginTop:-28,position:'relative',padding:'28px 26px 32px',textAlign:ar?'right':'left',boxShadow:'0 -12px 30px rgba(120,72,40,.12)'}}>
      <div style={{fontSize:11,fontWeight:700,letterSpacing:ar?'0':'.18em',textTransform:'uppercase',color:'var(--terracotta)'}}>{s.kicker}</div>
      <div style={{fontFamily:ar?'var(--font-arabic)':'var(--font-display)',fontSize:ar?26:32,fontWeight:ar?700:600,lineHeight:ar?1.4:1.15,margin:'8px 0 10px',color:'var(--text-body)',textWrap:'pretty',letterSpacing:ar?'0':'-.01em'}}>{s.title}</div>
      <div style={{fontSize:15,lineHeight:1.7,color:'var(--text-soft)'}}>{s.body}</div>
      <div style={{display:'flex',gap:6,margin:'20px 0'}}>{slides.map((_,k)=><span key={k} onClick={()=>setI(k)} style={{width:k===i?22:7,height:7,borderRadius:4,background:k===i?'var(--terracotta)':'var(--line)',cursor:'pointer',transition:'width .2s'}}></span>)}</div>
      <Button style={{width:'100%'}} onClick={()=>i<slides.length-1?setI(i+1):onStart&&onStart()}>{i<slides.length-1?u.next:u.start}</Button>
      <div style={{textAlign:'center',marginTop:16,fontSize:14,color:'var(--text-soft)'}}>{u.have} <span onClick={onSignIn} style={{color:'var(--terracotta)',fontWeight:600,cursor:'pointer'}}>{u.signin}</span></div>
    </div>
  </div>;
}