import React from 'react';
import {RestaurantCard} from '../../components/venue/RestaurantCard';
import {EmptyState} from '../../components/social/EmptyState';
import {Chip} from '../../components/core/Chip';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=900&q=80&auto=format&fit=crop';

const T={en:{title:'Saved',chips:['All','Date night','Rooftops','Want to try'],avail:'Tonight'},
ar:{title:'المحفوظة',chips:['الكل','عشاء رومانسي','رووف','ودّي أجرب'],avail:'الليلة'}};
const all=[
  {name:{en:'Kazoku',ar:'كازوكو'},rating:'4.9',reviews:210,cuisine:{en:'Japanese',ar:'ياباني'},price:'$$$$',neighbourhood:{en:'Garden City',ar:'جاردن سيتي'},image:IMG('1579027989536-b7b1f875659b'),at:'10:00'},
  {name:{en:'Zooba',ar:'زوبا'},rating:'4.7',reviews:1203,cuisine:{en:'Egyptian',ar:'مصري'},price:'$$',neighbourhood:{en:'Downtown',ar:'وسط البلد'},image:IMG('1555939594-58d7cb561ad1'),at:'7:45'},
  {name:{en:'Sachi',ar:'ساتشي'},rating:'4.5',reviews:880,cuisine:{en:'Fusion',ar:'فيوژن'},price:'$$$',neighbourhood:{en:'New Cairo',ar:'القاهرة الجديدة'},image:IMG('1517248135467-4c7edcad34c4')}
];
export function SavedScreen({onVenue,saved={},onSave,onDiscover,lang='en'}){
  const ar=lang==='ar';const t=T[lang]||T.en;const L=x=>ar?x.ar:x.en;
  const vp=v=>({name:L(v.name),cuisine:L(v.cuisine),neighbourhood:L(v.neighbourhood),rating:v.rating,reviews:v.reviews,price:v.price,image:v.image,availability:v.at?(t.avail+' · '+v.at+(ar?' م':' PM')):undefined});
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',overflowY:'auto',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>
    <div style={{padding:'22px 20px 4px',fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:28,fontWeight:600,letterSpacing:ar?'0':'-.01em'}}>{t.title}</div>
    <div style={{display:'flex',gap:8,padding:'12px 20px',overflowX:'auto'}}>{t.chips.map((c,i)=><Chip key={i} active={i===0} style={{flex:'0 0 auto'}}>{c}</Chip>)}</div>
    <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:14,padding:'8px 20px 24px'}}>
      {all.map(v=><RestaurantCard key={v.name.en} {...vp(v)} width="100%" imageHeight={110} saved onSave={()=>onSave&&onSave(v.name.en)} onClick={()=>onVenue&&onVenue(v)}/>)}
    </div>
  </div>;
}
