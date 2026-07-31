import React from 'react';
import {Button} from '../../components/core/Button';
import {Chip} from '../../components/core/Chip';
import {Icon} from '../../components/core/Icon';
import {Photo} from './Photo';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=900&q=80&auto=format&fit=crop';

const T={en:{title:'Book a table',date:'Date',party:'Party size',time:'Time',guest:'guest',guests:'guests',confirm:'Confirm for',at:'at',pm:'PM',free:'Free cancellation up to 2 hours before.',cuisine:'Levantine',full:'Fully booked',notify:'Notify me',notifying:'Watching',notifyHint:"We'll ping you if a table frees up.",
  days:[['Tonight','Wed 21'],['Thu','22'],['Fri','23'],['Sat','24'],['Sun','25'],['Mon','26']]},
ar:{title:'احجز طاولة',date:'التاريخ',party:'عدد الأفراد',time:'الوقت',guest:'فرد',guests:'أفراد',confirm:'أكّد لـ',at:'الساعة',pm:'م',free:'إلغاء مجاني حتى ساعتين قبل الموعد.',cuisine:'شامي',full:'مكتمل',notify:'بلّغني',notifying:'بنراقب',notifyHint:'هنبلّغك لو فضيت طاولة.',
  days:[['الليلة','الأربع 21'],['الخميس','22'],['الجمعة','23'],['السبت','24'],['الأحد','25'],['الاثنين','26']]}};
const slots=['6:00','6:30','7:00','7:30','7:45','8:00','8:30','9:00','9:15','9:45','10:00','10:30'];
const fullSlots=['7:30','8:00','8:30'];
export function BookingFlowScreen({venue={},onBack,onConfirm,lang='en'}){
  const ar=lang==='ar';const t=T[lang]||T.en;const L=x=>x&&(typeof x==='object')?(ar?x.ar:x.en):x;
  const v={name:{en:'Layali Lounge',ar:'ليالي لاونج'},image:IMG('1414235077428-338989a2e8c0'),neighbourhood:{en:'Zamalek',ar:'الزمالك'},...venue};
  const [day,setDay]=React.useState(0);
  const [party,setParty]=React.useState(2);
  const [time,setTime]=React.useState('9:00');
  const [watching,setWatching]=React.useState({});
  const toggleWatch=s=>setWatching(w=>({...w,[s]:!w[s]}));
  const step=d=>setParty(p=>Math.max(1,Math.min(12,p+d)));
  const stepBtn={width:40,height:40,borderRadius:'50%',border:'1px solid var(--line)',background:'var(--surface-card)',color:'var(--text-body)',fontSize:20,cursor:'pointer',lineHeight:1};
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',display:'flex',flexDirection:'column',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>
    <div style={{display:'flex',alignItems:'center',gap:12,padding:'20px 20px 14px'}}>
      <button onClick={onBack} style={{background:'none',border:'none',color:'var(--text-body)',cursor:'pointer',display:'flex',padding:0}}><Icon name={ar?'arrow-right':'arrow-left'} size={22}/></button>
      <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:21,fontWeight:600,letterSpacing:ar?'0':'-.01em'}}>{t.title}</div>
    </div>
    <div style={{flex:1,overflowY:'auto',padding:'0 20px 20px'}}>
      <div style={{display:'flex',gap:12,alignItems:'center',background:'var(--surface-card)',border:'1px solid var(--line)',borderRadius:'var(--radius-lg)',padding:10,marginBottom:22}}>
        <div style={{width:56}}><Photo image={v.image} height={56} radius={10}/></div>
        <div><div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:17,fontWeight:600,letterSpacing:ar?'0':'-.01em'}}>{L(v.name)}</div><div style={{fontSize:12,color:'var(--text-faint)'}}>{L(v.neighbourhood)} · {t.cuisine}</div></div>
      </div>
      <Label ar={ar}>{t.date}</Label>
      <div style={{display:'flex',gap:10,overflowX:'auto',paddingBottom:4,marginBottom:22}}>
        {t.days.map(([d,n],i)=><button key={i} onClick={()=>setDay(i)} style={{flex:'0 0 auto',minWidth:64,padding:'12px 0',borderRadius:'var(--radius-md)',border:'1px solid '+(day===i?'transparent':'var(--line)'),background:day===i?'var(--terracotta)':'transparent',color:day===i?'#fff':'var(--text-soft)',cursor:'pointer',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>
          <div style={{fontSize:11,opacity:.85}}>{d}</div><div style={{fontSize:15,fontWeight:700}}>{n}</div></button>)}
      </div>
      <Label ar={ar}>{t.party}</Label>
      <div style={{display:'flex',alignItems:'center',justifyContent:'center',gap:24,margin:'6px 0 24px'}}>
        <button style={stepBtn} onClick={()=>step(-1)}>&minus;</button>
        <div style={{textAlign:'center'}}><div style={{fontSize:32,fontWeight:700}}>{party}</div><div style={{fontSize:11,color:'var(--text-faint)'}}>{party===1?t.guest:t.guests}</div></div>
        <button style={stepBtn} onClick={()=>step(1)}>+</button>
      </div>
      <Label ar={ar}>{t.time}</Label>
      <div style={{display:'flex',gap:8,flexWrap:'wrap',marginTop:4}}>{slots.map(s=>{
        const full=fullSlots.includes(s);
        if(!full)return <Chip key={s} active={time===s} onClick={()=>setTime(s)}>{s} {t.pm}</Chip>;
        const on=!!watching[s];
        return <button key={s} onClick={()=>toggleWatch(s)} title={t.notifyHint} style={{display:'inline-flex',alignItems:'center',gap:6,padding:'8px 14px',borderRadius:'var(--radius-pill)',fontSize:13,fontWeight:600,fontFamily:ar?'var(--font-arabic)':'var(--font-latin)',cursor:'pointer',border:'1px dashed '+(on?'var(--gold-dark)':'var(--line)'),background:on?'var(--gold-tint)':'transparent',color:on?'var(--gold-dark)':'var(--text-faint)'}}>
          <Icon name="bell" size={13}/><span style={{textDecoration:on?'none':'line-through',opacity:on?1:.8}}>{s} {t.pm}</span>{on&&<span style={{fontSize:10,fontWeight:700}}>✓</span>}
        </button>;
      })}</div>
      {Object.values(watching).some(Boolean)&&<div style={{display:'flex',alignItems:'center',gap:8,marginTop:14,fontSize:12,color:'var(--gold-dark)'}}><Icon name="bell" size={14}/>{t.notifyHint}</div>}
    </div>
    <div style={{padding:'14px 20px',borderTop:'1px solid var(--line)',background:'var(--surface-page)'}}>
      <Button style={{width:'100%'}} onClick={()=>onConfirm&&onConfirm({venue:v,party,time:time+' '+t.pm,day:t.days[day].join(' ')})}>{t.confirm} {party} {t.at} {time} {t.pm}</Button>
      <div style={{fontSize:12,color:'var(--text-faint)',textAlign:'center',marginTop:10}}>{t.free}</div>
    </div>
  </div>;
}
function Label({children,ar}){return <div style={{fontSize:11,fontWeight:700,letterSpacing:ar?'0':'.14em',textTransform:ar?'none':'uppercase',color:'var(--text-faint)',marginBottom:10}}>{children}</div>;}
