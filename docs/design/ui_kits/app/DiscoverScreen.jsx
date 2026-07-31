import React from 'react';
import {RestaurantCard} from '../../components/venue/RestaurantCard';
import {Avatar} from '../../components/social/Avatar';
import {Badge} from '../../components/core/Badge';
import {Icon} from '../../components/core/Icon';
import {Photo} from './Photo';
import {SkeletonCard} from '../../components/core/Skeleton';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=900&q=80&auto=format&fit=crop';

const T={en:{eve:'Good evening, Nour',loc:'Zamalek, Cairo',avail:'Available tonight',all:'See all',coll:'Collections',browse:'Browse',iftar:'Iftar tables, sorted',iftarSub:'Break your fast somewhere memorable',places:'places',ramadan:'Ramadan',events:'Tonight in Cairo',rate:'How was Zooba?',rateSub:'Friday · table for 2 · tap to rate',offer:'20% off before 7:30'},
ar:{eve:'مساء الخير يا نور',loc:'الزمالك، القاهرة',avail:'متاح الليلة',all:'الكل',coll:'مجموعات',browse:'تصفّح',iftar:'موائد الإفطار، جاهزة',iftarSub:'افطر في مكان يستاهل',places:'مكان',ramadan:'رمضان',events:'الليلة في القاهرة',rate:'إزاي كانت زوبا؟',rateSub:'الجمعة · طاولة لـ 2 · اضغط للتقييم',offer:'خصم 20٪ قبل 7:30'}};
const tonight=[
  {name:{en:'Layali Lounge',ar:'ليالي لاونج'},rating:'4.8',reviews:312,cuisine:{en:'Levantine',ar:'شامي'},price:'$$$',neighbourhood:{en:'Zamalek',ar:'الزمالك'},image:IMG('1414235077428-338989a2e8c0'),featured:true,at:'9:00'},
  {name:{en:'Sequoia',ar:'سيكويا'},rating:'4.6',reviews:540,cuisine:{en:'Mediterranean',ar:'متوسطي'},price:'$$$',neighbourhood:{en:'Zamalek',ar:'الزمالك'},image:IMG('1466978913421-dad2ebd01d17'),at:'8:30'},
  {name:{en:'Zooba',ar:'زوبا'},rating:'4.7',reviews:1203,cuisine:{en:'Egyptian',ar:'مصري'},price:'$$',neighbourhood:{en:'Downtown',ar:'وسط البلد'},image:IMG('1555939594-58d7cb561ad1'),at:'7:45'}
];
const collections=[{t:{en:'Rooftops with a view',ar:'رووف بإطلالة'},n:12,image:IMG('1600891964092-4316c288032e')},{t:{en:'Late-night kitchens',ar:'مطابخ لوقت متأخر'},n:8,image:IMG('1517248135467-4c7edcad34c4')},{t:{en:'Nile-side terraces',ar:'تراسات على النيل'},n:15,image:IMG('1470337458703-46ad1756a187')}];
const events=[
  {t:{en:'Live oud · Layali Lounge',ar:'عود حي · ليالي لاونج'},when:{en:'10 PM · no cover',ar:'10 م · بدون رسوم'},image:IMG('1511671782779-c97d3d27a1d4')},
  {t:{en:'Omakase night · Kazoku',ar:'ليلة أوماكاسي · كازوكو'},when:{en:'Ticketed · EGP 1,800',ar:'بتذكرة · 1,800 ج.م'},image:IMG('1579027989536-b7b1f875659b'),ticketed:true},
  {t:{en:'Suhoor on the terrace · Sequoia',ar:'سحور على التراس · سيكويا'},when:{en:'From 1 AM',ar:'من 1 ص'},image:IMG('1470337458703-46ad1756a187')}
];
export function DiscoverScreen({onVenue,onOccasion,onSave,saved={},lang='en'}){
  const ar=lang==='ar';const t=T[lang]||T.en;const L=x=>ar?x.ar:x.en;
  const scrollRef=React.useRef(null);
  const drag=React.useRef({on:false,y0:0});
  const [pull,setPull]=React.useState(0);          // 0..1 of threshold
  const [refreshing,setRefreshing]=React.useState(false);
  const TH=90;
  const onDown=e=>{if(scrollRef.current.scrollTop<=0){drag.current={on:true,y0:e.clientY}}};
  const onMove=e=>{
    if(!drag.current.on||refreshing)return;
    const d=e.clientY-drag.current.y0;
    if(d>0&&scrollRef.current.scrollTop<=0){setPull(Math.min(1,d/TH));e.preventDefault()}
  };
  const onUp=()=>{
    if(!drag.current.on)return;drag.current.on=false;
    if(pull>=1&&!refreshing){setRefreshing(true);setTimeout(()=>{setRefreshing(false);setPull(0)},1300)}
    else setPull(0);
  };
  const [rated,setRated]=React.useState(0);
  const availTxt=v=>ar?('2 · الليلة · '+v.at+' م'):('2 · Tonight · '+v.at+' PM');
  const vprops=v=>({name:L(v.name),cuisine:L(v.cuisine),neighbourhood:L(v.neighbourhood),rating:v.rating,reviews:v.reviews,price:v.price,image:v.image,featured:v.featured,availability:availTxt(v)});
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',position:'relative',overflow:'hidden',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>
    <style>{`@keyframes sahraLanternSwing{0%,100%{transform:rotate(-7deg)}50%{transform:rotate(7deg)}}`}</style>
    <div aria-hidden="true" style={{position:'absolute',top:0,left:0,right:0,height:64,display:'flex',alignItems:'center',justifyContent:'center',zIndex:4,pointerEvents:'none',transform:'translateY('+((refreshing?1:pull)*64-64)+'px)',opacity:refreshing?1:pull,transition:drag.current.on?'none':'transform .25s ease,opacity .25s ease'}}>
      <span style={{color:pull>=1||refreshing?'var(--gold)':'var(--text-faint)',display:'flex',transform:refreshing?'none':'scale('+(0.6+0.4*pull)+')',animation:refreshing?'sahraLanternSwing .9s ease-in-out infinite':'none',transformOrigin:'50% 0'}}><Icon name="lantern" size={24}/></span>
    </div>
    <div ref={scrollRef} onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp} style={{height:'100%',overflowY:'auto',touchAction:'pan-y',transform:'translateY('+((refreshing?1:pull)*54)+'px)',transition:drag.current.on?'none':'transform .25s ease'}}>
    <div style={{padding:'22px 20px 0',display:'flex',alignItems:'center',justifyContent:'space-between'}}>
      <div>
        <div style={{fontSize:12,color:'var(--text-faint)'}}>{t.eve}</div>
        <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:22,fontWeight:600,letterSpacing:ar?'0':'-.01em',display:'flex',alignItems:'center',gap:6}}>{t.loc} <Icon name="chevron-down" size={18} style={{color:'var(--gold)'}}/></div>
      </div>
      <Avatar name="Nour Hassan" src={IMG('1544005313-94ddf0286df2')} size={40}/>
    </div>
    <div onClick={onOccasion} style={{margin:'18px 20px 0',borderRadius:'var(--radius-lg)',overflow:'hidden',position:'relative',cursor:'pointer'}}>
      <Photo image={IMG('1528702748617-c64d49f918af')} height={104} gradientOverlay/>
      <div style={{position:'absolute',inset:0,padding:'16px 18px',display:'flex',flexDirection:'column',justifyContent:'flex-end'}}>
        <Badge variant="gold" style={{alignSelf:'flex-start',marginBottom:6}}>{t.ramadan}</Badge>
        <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:20,fontWeight:600,letterSpacing:ar?'0':'-.01em',color:'#FDFBF7'}}>{t.iftar}</div>
        <div style={{fontSize:12,color:'rgba(253,251,247,.85)'}}>{t.iftarSub} {ar?'←':'→'}</div>
      </div>
    </div>
    <div style={{margin:'14px 20px 0',display:'flex',alignItems:'center',gap:12,background:'var(--surface-card)',border:'1px solid var(--line)',borderRadius:'var(--radius-lg)',padding:'12px 14px'}}>
      <div style={{flex:1}}>
        <div style={{fontSize:14,fontWeight:600}}>{t.rate}</div>
        <div style={{fontSize:11,color:'var(--text-faint)',marginTop:2}}>{t.rateSub}</div>
      </div>
      <div style={{display:'flex',gap:4}}>{[1,2,3,4,5].map(i=><button key={i} onClick={()=>setRated(i)} aria-label={'rate '+i} style={{background:'none',border:'none',padding:2,cursor:'pointer',color:i<=rated?'var(--gold)':'var(--text-faint)',display:'flex'}}><Icon name="star" size={18} style={i<=rated?{fill:'currentColor'}:{}}/></button>)}</div>
    </div>
    <SectionTitle title={t.avail} action={t.all} ar={ar}/>
    <div style={{display:'flex',gap:14,overflowX:'auto',padding:'0 20px 4px'}}>
      {refreshing?[1,2,3].map(i=><SkeletonCard key={i} style={{flex:'0 0 auto',width:244}}/>):tonight.map(v=><RestaurantCard key={v.name.en} {...vprops(v)} width={244} imageHeight={140} saved={!!saved[v.name.en]} onSave={()=>onSave&&onSave(v.name.en)} onClick={()=>onVenue&&onVenue(v)} style={{flex:'0 0 auto'}}/>)}
    </div>
    <SectionTitle title={t.events} ar={ar}/>
    <div style={{display:'flex',gap:12,overflowX:'auto',padding:'0 20px 4px'}}>
      {events.map(e=><div key={e.t.en} onClick={()=>onVenue&&onVenue(tonight[0])} style={{flex:'0 0 auto',width:200,borderRadius:'var(--radius-lg)',overflow:'hidden',position:'relative',cursor:'pointer'}}>
        <Photo image={e.image} height={120} gradientOverlay/>
        <div style={{position:'absolute',inset:0,padding:'12px 14px',display:'flex',flexDirection:'column',justifyContent:'flex-end'}}>
          <div style={{fontSize:14,fontWeight:600,color:'#FDFBF7',lineHeight:1.3}}>{L(e.t)}</div>
          <div style={{fontSize:11,color:'rgba(253,251,247,.85)',marginTop:3,display:'flex',alignItems:'center',gap:5}}>{e.ticketed&&<Icon name="ticket" size={12}/>}{L(e.when)}</div>
        </div>
      </div>)}
    </div>
    <SectionTitle title={t.coll} action={t.browse} ar={ar}/>
    <div style={{display:'flex',flexDirection:'column',gap:12,padding:'0 20px 24px'}}>
      {collections.map(c=><div key={c.t.en} onClick={()=>onVenue&&onVenue(tonight[0])} style={{position:'relative',borderRadius:'var(--radius-lg)',overflow:'hidden',cursor:'pointer'}}>
        <Photo image={c.image} height={92} gradientOverlay/>
        <div style={{position:'absolute',inset:0,padding:'0 18px',display:'flex',flexDirection:'column',justifyContent:'center'}}>
          <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:19,fontWeight:600,letterSpacing:ar?'0':'-.01em',color:'#FDFBF7'}}>{L(c.t)}</div>
          <div style={{fontSize:12,color:'rgba(253,251,247,.8)'}}>{c.n} {t.places}</div>
        </div>
      </div>)}
    </div>
    </div>
  </div>;
}
function SectionTitle({title,action,ar}){
  return <div style={{display:'flex',alignItems:'baseline',justifyContent:'space-between',padding:'22px 20px 12px'}}>
    <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:22,fontWeight:600,letterSpacing:ar?'0':'-.01em',color:'var(--text-body)'}}>{title}</div>
    {action&&<div style={{fontSize:13,fontWeight:600,color:'var(--gold-dark)',cursor:'pointer'}}>{action}</div>}
  </div>;
}
