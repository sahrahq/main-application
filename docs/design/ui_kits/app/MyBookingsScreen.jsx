import React from 'react';
import {Badge} from '../../components/core/Badge';
import {Icon} from '../../components/core/Icon';
import {EmptyState} from '../../components/social/EmptyState';
import {DiningTrail} from '../../components/brand/DiningTrail';
import {Photo} from './Photo';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=900&q=80&auto=format&fit=crop';

const T={en:{title:'My bookings',tabs:['Upcoming','Past'],confirmed:'Confirmed',tonight:'Tonight',waitlist:'Waitlist',guests:'guests',watching:'Watching for a table',watchHint:"We'll ping you the moment one frees up",trail:n=>'Your dining trail · '+n+' evenings out'},
ar:{title:'حجوزاتي',tabs:['القادمة','السابقة'],confirmed:'مؤكّد',tonight:'الليلة',waitlist:'قائمة انتظار',guests:'أفراد',watching:'بنراقب طاولة',watchHint:'هنبلّغك أول ما تفضى واحدة',trail:n=>'رحلتك · '+n+' سهرات'}};
const upcoming=[
  {name:{en:'Layali Lounge',ar:'ليالي لاونج'},image:IMG('1414235077428-338989a2e8c0'),when:{en:'Tonight · 9:00 PM',ar:'الليلة · 9:00 م'},party:2,status:'confirmed',tonight:true},
  {name:{en:'Sequoia',ar:'سيكويا'},image:IMG('1466978913421-dad2ebd01d17'),when:{en:'Sat 24 · 8:30 PM',ar:'السبت 24 · 8:30 م'},party:4,status:'waitlist'}
];
const past={en:[{name:'Zooba',date:'Fri 16 Feb',note:'Table for 2'},{name:'Kazoku',date:'Sat 3 Feb',note:'Omakase · 4 guests'},{name:'Sachi',date:'Thu 25 Jan',note:'Table for 2'},{name:'Khan El Khalili',date:'Ramadan · 12 Jan',note:'Iftar · 6 guests'}],
ar:[{name:'زوبا',date:'الجمعة 16 فبراير',note:'طاولة لـ 2'},{name:'كازوكو',date:'السبت 3 فبراير',note:'أوماكاسي · 4 أفراد'},{name:'ساتشي',date:'الخميس 25 يناير',note:'طاولة لـ 2'},{name:'خان الخليلي',date:'رمضان · 12 يناير',note:'إفطار · 6 أفراد'}]};
export function MyBookingsScreen({onVenue,onDiscover,lang='en'}){
  const ar=lang==='ar';const t=T[lang]||T.en;const L=x=>ar?x.ar:x.en;
  const [tab,setTab]=React.useState('upcoming');
  const pastList=ar?past.ar:past.en;
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',display:'flex',flexDirection:'column',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>
    <div style={{padding:'22px 20px 6px',fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:28,fontWeight:600,letterSpacing:ar?'0':'-.01em'}}>{t.title}</div>
    <div style={{display:'flex',gap:24,padding:'8px 20px 0',borderBottom:'1px solid var(--line)'}}>
      {[['upcoming',t.tabs[0]],['past',t.tabs[1]]].map(([id,l])=><button key={id} onClick={()=>setTab(id)} style={{background:'none',border:'none',cursor:'pointer',padding:'0 0 12px',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)',fontSize:14,fontWeight:700,color:tab===id?'var(--text-body)':'var(--text-faint)',borderBottom:tab===id?'2px solid var(--terracotta)':'2px solid transparent'}}>{l}</button>)}
    </div>
    <div style={{flex:1,overflowY:'auto',padding:'16px 20px'}}>
      {tab==='upcoming'?<div style={{display:'flex',flexDirection:'column',gap:14}}>
      <div style={{display:'flex',alignItems:'center',gap:12,border:'1px dashed var(--gold-dark)',borderRadius:'var(--radius-lg)',padding:'12px 14px',background:'var(--gold-tint)'}}>
        <span style={{color:'var(--gold-dark)',display:'flex'}}><Icon name="bell" size={18}/></span>
        <div style={{flex:1}}>
          <div style={{fontSize:13,fontWeight:700,color:'var(--gold-dark)'}}>{t.watching} · {ar?'كازوكو':'Kazoku'} · {ar?'الجمعة 23 · 8:30 م':'Fri 23 · 8:30 PM'}</div>
          <div style={{fontSize:11,color:'var(--text-faint)',marginTop:2}}>{t.watchHint}</div>
        </div>
      </div>
      {upcoming.map(b=><div key={b.name.en} onClick={()=>onVenue&&onVenue(b)} style={{display:'flex',gap:14,background:'var(--surface-card)',border:'1px solid '+(b.tonight?'rgba(224,169,109,.5)':'var(--line)'),borderRadius:'var(--radius-lg)',padding:12,cursor:'pointer',boxShadow:b.tonight?'0 0 24px rgba(224,169,109,.16)':'none'}}>
        <div style={{width:64}}><Photo image={b.image} height={64} radius={12}/></div>
        <div style={{flex:1}}>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start'}}><span style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:17,fontWeight:600,letterSpacing:ar?'0':'-.01em'}}>{L(b.name)}</span>{b.status==='waitlist'?<Badge variant="warning">{t.waitlist}</Badge>:<Badge variant={b.tonight?'gold':'success'}>{b.tonight?t.tonight:t.confirmed}</Badge>}</div>
          <div style={{fontSize:13,color:'var(--text-soft)',marginTop:6,display:'flex',alignItems:'center',gap:6}}><Icon name={b.tonight?'lantern':'calendar'} size={14} style={{color:'var(--gold)'}}/>{L(b.when)}</div>
          <div style={{fontSize:13,color:'var(--text-faint)',marginTop:3,display:'flex',alignItems:'center',gap:6}}><Icon name="users" size={14}/>{b.party} {t.guests}</div>
        </div>
      </div>)}</div>:
      <div><div style={{fontSize:12,color:'var(--text-faint)',marginBottom:18}}>{t.trail(pastList.length)}</div><DiningTrail visits={pastList}/></div>}
    </div>
  </div>;
}
