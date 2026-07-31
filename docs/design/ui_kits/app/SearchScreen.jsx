import React from 'react';
import {SearchBar} from '../../components/navigation/SearchBar';
import {Chip} from '../../components/core/Chip';
import {Badge} from '../../components/core/Badge';
import {Icon} from '../../components/core/Icon';
import {RatingStars} from '../../components/venue/RatingStars';
import {MapCard} from './MapCard';
import {Photo} from './Photo';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=900&q=80&auto=format&fit=crop';

const T={en:{chips:['Tonight','Collections','Lists','Events'],open:'11 places open tonight',next:'Next',search:'Search',city:'CAIRO',expand:'Expand map',collapse:'Collapse'},
ar:{chips:['الليلة','مجموعات','قوائم','فعاليات'],open:'11 مكان مفتوح الليلة',next:'القادم',search:'ابحث',city:'القاهرة',expand:'كبّر الخريطة',collapse:'صغّر'}};
const results=[
  {name:{en:'Layali Lounge',ar:'ليالي لاونج'},rating:'4.8',reviews:312,cuisine:{en:'Levantine',ar:'شامي'},price:'$$$',image:IMG('1414235077428-338989a2e8c0'),time:'9:00',pos:[30.0622,31.2185]},
  {name:{en:'Sequoia',ar:'سيكويا'},rating:'4.6',reviews:540,cuisine:{en:'Mediterranean',ar:'متوسطي'},price:'$$$',image:IMG('1466978913421-dad2ebd01d17'),time:'8:30',pos:[30.0742,31.2249]},
  {name:{en:'Kazoku',ar:'كازوكو'},rating:'4.9',reviews:210,cuisine:{en:'Japanese',ar:'ياباني'},price:'$$$$',image:IMG('1579027989536-b7b1f875659b'),time:'10:00',pos:[30.0585,31.2228]}
];
export function SearchScreen({onVenue,lang='en'}){
  const ar=lang==='ar';const t=T[lang]||T.en;const L=x=>ar?x.ar:x.en;
  const [chip,setChip]=React.useState(0);
  const [big,setBig]=React.useState(false);
  const pins=results.map(v=>({name:L(v.name),pos:v.pos,time:v.time,venue:v}));
  const vp=v=>({name:L(v.name),cuisine:L(v.cuisine),rating:v.rating,reviews:v.reviews,price:v.price,image:v.image});
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',display:'flex',flexDirection:'column',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>
    <div style={{padding:'22px 20px 12px',display:'flex',flexDirection:'column',gap:12}}>
      <SearchBar placeholder={t.search} location={t.city}/>
      <div style={{display:'flex',gap:8,overflowX:'auto'}}>{t.chips.map((c,i)=><Chip key={i} active={chip===i} onClick={()=>setChip(i)} style={{flex:'0 0 auto'}}>{c}</Chip>)}</div>
    </div>
    <div style={{flex:1,overflowY:'auto',padding:'0 20px 20px'}}>
      <div style={{position:'relative'}}>
        <MapCard height={big?400:170} city={t.city} pins={pins} onPin={p=>onVenue&&onVenue(p.venue)}/>
        <button onClick={()=>setBig(!big)} style={{position:'absolute',insetInlineEnd:10,top:10,zIndex:3,width:30,height:30,borderRadius:'50%',border:'1px solid var(--line)',background:'var(--surface-card)',color:'var(--text-soft)',cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center'}} aria-label={big?t.collapse:t.expand}><Icon name={big?'chevron-up':'compass'} size={15}/></button>
      </div>
      <div style={{fontSize:13,color:'var(--text-faint)',margin:'16px 0 10px'}}>{t.open}</div>
      <div style={{display:'flex',flexDirection:'column',gap:12}}>
        {results.map(v=>{const p=vp(v);return <div key={v.name.en} onClick={()=>onVenue&&onVenue(v)} style={{display:'flex',gap:12,background:'var(--surface-card)',border:'1px solid var(--line)',borderRadius:'var(--radius-lg)',padding:10,cursor:'pointer'}}>
          <div style={{width:76,flexShrink:0}}><Photo image={p.image} height={76} radius={12}/></div>
          <div style={{flex:1,minWidth:0}}>
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}><span style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:17,fontWeight:600,letterSpacing:ar?'0':'-.01em'}}>{p.name}</span><Icon name="heart" size={16} style={{color:'var(--text-faint)'}}/></div>
            <div style={{marginTop:3}}><RatingStars rating={p.rating} reviews={p.reviews} size={12}/><span style={{fontSize:12,color:'var(--text-faint)'}}> · {p.cuisine} · {p.price}</span></div>
            <div style={{marginTop:8}}><Badge variant="featured" style={{fontSize:10}}>{t.next}: {v.time} {ar?'م':'PM'}</Badge></div>
          </div>
        </div>;})}
      </div>
    </div>
  </div>;
}
