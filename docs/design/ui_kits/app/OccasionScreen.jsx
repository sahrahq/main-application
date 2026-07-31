import React from 'react';
import {Icon} from '../../components/core/Icon';
import {Badge} from '../../components/core/Badge';
import {RestaurantCard} from '../../components/venue/RestaurantCard';
import {Photo} from './Photo';
import {Mashrabiya} from '../../components/brand/Mashrabiya';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=900&q=80&auto=format&fit=crop';

const T={en:{badge:'Ramadan 1447',title:'Iftar, sorted',sub:'Break your fast somewhere memorable.',intro:'Sunset is at 6:04 PM tonight. These tables hold your iftar seating and serve the moment the cannon sounds.',section:'Iftar tables tonight',avail:'Iftar · 6:10 PM'},
ar:{badge:'رمضان 1447',title:'الإفطار، جاهز',sub:'افطر في مكان يستاهل.',intro:'المغرب الليلة الساعة 6:04 م. الموائد دي بتحجزلك مكان للإفطار وبتقدّم أول ما يضرب المدفع.',section:'موائد الإفطار الليلة',avail:'إفطار · 6:10 م'}};
const iftar=[
  {name:{en:'Layali Lounge',ar:'ليالي لاونج'},rating:'4.8',reviews:312,cuisine:{en:'Levantine',ar:'شامي'},price:'$$$',neighbourhood:{en:'Zamalek',ar:'الزمالك'},image:IMG('1414235077428-338989a2e8c0')},
  {name:{en:'Khan El Khalili',ar:'خان الخليلي'},rating:'4.6',reviews:702,cuisine:{en:'Egyptian',ar:'مصري'},price:'$$$',neighbourhood:{en:'Old Cairo',ar:'مصر القديمة'},image:IMG('1555939594-58d7cb561ad1')}
];
export function OccasionScreen({onBack,onVenue,onSave,saved={},lang='en'}){
  const ar=lang==='ar';const t=T[lang]||T.en;const L=x=>ar?x.ar:x.en;
  const vp=v=>({name:L(v.name),cuisine:L(v.cuisine),neighbourhood:L(v.neighbourhood),rating:v.rating,reviews:v.reviews,price:v.price,image:v.image,availability:t.avail});
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',overflowY:'auto',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>
    <div style={{position:'relative'}}>
      <Photo image={IMG('1528702748617-c64d49f918af')} height={210} gradientOverlay/>
      <Mashrabiya color="rgba(224,169,109,0.22)" tile={46} style={{height:210}}/>
      <button onClick={onBack} style={{position:'absolute',top:20,insetInlineStart:20,width:38,height:38,borderRadius:'50%',border:'none',background:'rgba(20,12,8,.5)',backdropFilter:'blur(6px)',color:'#FDFBF7',cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={ar?'arrow-right':'arrow-left'} size={18}/></button>
      <div style={{position:'absolute',insetInlineStart:20,insetInlineEnd:20,bottom:20,textAlign:ar?'right':'left'}}>
        <Badge variant="gold" style={{marginBottom:8}}>{t.badge}</Badge>
        <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:30,fontWeight:600,color:'#FDFBF7',letterSpacing:ar?'0':'-.01em'}}>{t.title}</div>
        <div style={{fontSize:14,color:'rgba(253,251,247,.85)',marginTop:4}}>{t.sub}</div>
      </div>
    </div>
    <div style={{padding:'20px 20px 6px',fontSize:14,color:'var(--text-soft)',lineHeight:1.7,textAlign:ar?'right':'left'}}>{t.intro}</div>
    <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:21,fontWeight:600,padding:'16px 20px 12px',letterSpacing:ar?'0':'-.01em'}}>{t.section}</div>
    <div style={{display:'flex',flexDirection:'column',gap:14,padding:'0 20px 28px'}}>
      {iftar.map(v=><RestaurantCard key={v.name.en} {...vp(v)} width="100%" saved={!!saved[v.name.en]} onSave={()=>onSave&&onSave(v.name.en)} onClick={()=>onVenue&&onVenue(v)}/>)}
    </div>
  </div>;
}
