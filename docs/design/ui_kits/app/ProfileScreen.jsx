import React from 'react';
import {Avatar} from '../../components/social/Avatar';
import {Button} from '../../components/core/Button';
import {Icon} from '../../components/core/Icon';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=900&q=80&auto=format&fit=crop';

const T={en:{since:'Member since 2024 · Cairo',stats:[['12','Bookings'],['34','Saved'],['4.9','Rating']],rows:[['calendar-check','My bookings'],['heart','Saved places'],['users','Invite friends'],['bell','Notifications'],['credit-card','Payment methods'],['globe','Language · English'],['circle-help','Help & support']],out:'Sign out',mybk:'My bookings',pts:'240 points',ptsTo:'60 to your free dessert at Zööba'},
ar:{since:'عضو منذ 2024 · القاهرة',stats:[['12','حجوزات'],['34','محفوظة'],['4.9','تقييم']],rows:[['calendar-check','حجوزاتي'],['heart','الأماكن المحفوظة'],['users','ادعُ أصدقاءك'],['bell','الإشعارات'],['credit-card','طرق الدفع'],['globe','اللغة · العربية'],['circle-help','المساعدة والدعم']],out:'تسجيل الخروج',mybk:'حجوزاتي',pts:'240 نقطة',ptsTo:'باقي 60 نقطة على الحلو المجاني في زوبا'}};
export function ProfileScreen({onBookings,lang='en'}){
  const ar=lang==='ar';const t=T[lang]||T.en;
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',overflowY:'auto',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>
    <div style={{padding:'30px 20px 22px',display:'flex',flexDirection:'column',alignItems:'center',textAlign:'center',borderBottom:'1px solid var(--line)'}}>
      <Avatar name="Nour Hassan" src={IMG('1544005313-94ddf0286df2')} size={76}/>
      <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:23,fontWeight:600,marginTop:12,letterSpacing:ar?'0':'-.01em'}}>{ar?'نور حسن':'Nour Hassan'}</div>
      <div style={{fontSize:13,color:'var(--text-faint)'}}>{t.since}</div>
      <div style={{display:'flex',gap:0,marginTop:18,width:'100%'}}>
        {t.stats.map(([n,l],i)=><div key={l} style={{flex:1,borderInlineStart:i?'1px solid var(--line)':'none'}}><div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:20,fontWeight:600,color:'var(--gold)'}}>{n}</div><div style={{fontSize:11,color:'var(--text-faint)'}}>{l}</div></div>)}
      </div>
    </div>
    <div style={{padding:'14px 20px 0'}}>
      <div style={{display:'flex',alignItems:'center',gap:12,padding:'13px 16px',background:'var(--surface-card)',border:'1px solid var(--line)',borderRadius:12}}>
        <span style={{color:'var(--gold-dark)',display:'flex'}}><Icon name="spark" size={20}/></span>
        <div style={{flex:1,minWidth:0}}>
          <div style={{display:'flex',alignItems:'baseline',gap:8}}>
            <span style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:16,fontWeight:600,color:'var(--gold-dark)'}}>{t.pts}</span>
            <span style={{fontSize:12,color:'var(--text-faint)'}}>{t.ptsTo}</span>
          </div>
          <div style={{height:4,borderRadius:999,background:'var(--line)',marginTop:8,overflow:'hidden'}}>
            <div style={{width:'80%',height:'100%',borderRadius:999,background:'var(--gold)'}}></div>
          </div>
        </div>
      </div>
    </div>
    <div style={{padding:'8px 8px 20px'}}>
      {t.rows.map(([ic,l],i)=><button key={i} onClick={i===0?onBookings:undefined} style={{width:'100%',display:'flex',alignItems:'center',gap:14,padding:'15px 14px',background:'none',border:'none',borderBottom:'1px solid var(--line)',cursor:'pointer',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)',color:'var(--text-body)',textAlign:ar?'right':'left'}}>
        <span style={{color:'var(--terracotta)',display:'flex'}}><Icon name={ic} size={19}/></span>
        <span style={{flex:1,fontSize:15}}>{l}</span>
        <Icon name={ar?'chevron-left':'chevron-right'} size={17} style={{color:'var(--text-faint)'}}/>
      </button>)}
      <div style={{padding:'20px 14px 0'}}><Button variant="secondary" style={{width:'100%'}}>{t.out}</Button></div>
    </div>
  </div>;
}
