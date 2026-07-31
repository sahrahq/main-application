import React from 'react';
import {Button} from '../../components/core/Button';
import {Badge} from '../../components/core/Badge';
import {Icon} from '../../components/core/Icon';
import {RatingStars} from '../../components/venue/RatingStars';
import {AvatarStack} from '../../components/social/AvatarStack';
import {Photo} from './Photo';
import {MapCard} from './MapCard';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=900&q=80&auto=format&fit=crop';

const T={en:{featured:'Featured tonight',friends:'Nour & 11 friends have been here',desc:'A Nile-side terrace built for long evenings — mezze, charcoal grills and live oud after ten. Come for the sunset call to prayer, stay for the last table standing.',info:[['clock','Open tonight','6:00 PM – 2:00 AM'],['map-pin','26th of July St, Zamalek','Get directions'],['phone','+20 2 2735 0000','Call venue']],from:'From',free:'Free to book',book:'Book a table',menu:'From the menu',fullMenu:'Full menu',offer:'Sunset offer — 20% off tables before 7:30 PM',egp:'EGP'},
ar:{featured:'مميز الليلة',friends:'نور و١١ صديق جرّبوا المكان',desc:'تراس على النيل متصمم للسهرات الطويلة — مقبّلات، مشويات على الفحم، وعود حي بعد العاشرة. تعالى لأذان المغرب، واقعد لآخر طاولة.',info:[['clock','مفتوح الليلة','6:00 م – 2:00 ص'],['map-pin','شارع 26 يوليو، الزمالك','الاتجاهات'],['phone','+20 2 2735 0000','اتصل بالمكان']],from:'يبدأ من',free:'الحجز مجاني',book:'احجز طاولة',menu:'من المنيو',fullMenu:'المنيو كامل',offer:'عرض الغروب — خصم 20٪ على الطاولات قبل 7:30 م',egp:'ج.م'}};
const menu={en:[['Charred halloumi & date honey','Mezze','320'],['Mixed grill for two','Charcoal','980'],['Freekeh-stuffed pigeon','Signature','540'],['Umm Ali, pistachio crust','Dessert','210']],
ar:[['حلومي مشوي بعسل البلح','مقبّلات','320'],['مشوي مشكل لفردين','فحم','980'],['حمام محشي فريك','أطباق مميزة','540'],['أم علي بالفستق','حلو','210']]};
const friends=[{name:'Nour H',src:IMG('1544005313-94ddf0286df2')},{name:'Omar A',src:IMG('1507003211169-0a1dd7228f2d')},{name:'Laila F',src:IMG('1438761681033-6461ffad8d80')},{name:'K M'},{name:'S T'}];
const gallery=['1414235077428-338989a2e8c0','1600891964092-4316c288032e','1470337458703-46ad1756a187','1517248135467-4c7edcad34c4'];
export function VenueDetailScreen({venue={},onBack,onBook,onSave,saved,lang='en'}){
  const ar=lang==='ar';const t=T[lang]||T.en;const L=x=>x&&(typeof x==='object')?(ar?x.ar:x.en):x;
  const v={name:{en:'Layali Lounge',ar:'ليالي لاونج'},rating:'4.8',reviews:312,cuisine:{en:'Levantine',ar:'شامي'},price:'$$$',neighbourhood:{en:'Zamalek',ar:'الزمالك'},image:IMG('1414235077428-338989a2e8c0'),...venue};
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',display:'flex',flexDirection:'column',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>
    <div style={{flex:1,overflowY:'auto'}}>
      <div style={{position:'relative'}}>
        <Photo image={v.image} height={280} gradientOverlay/>
        <div style={{position:'absolute',top:20,left:20,right:20,display:'flex',justifyContent:'space-between'}}>
          <IconBtn name={ar?'arrow-right':'arrow-left'} onClick={onBack}/>
          <div style={{display:'flex',gap:10}}><IconBtn name="share" /><IconBtn name="heart" active={saved} onClick={onSave}/></div>
        </div>
        <div style={{position:'absolute',left:20,right:20,bottom:18,textAlign:ar?'right':'left'}}>
          <Badge variant="featured" style={{marginBottom:8}}>{t.featured}</Badge>
          <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:30,fontWeight:600,color:'#FDFBF7',letterSpacing:ar?'0':'-.01em'}}>{L(v.name)}</div>
          <div style={{display:'flex',alignItems:'center',gap:8,marginTop:4,color:'rgba(253,251,247,.9)',fontSize:13,flexWrap:'wrap'}}><RatingStars rating={v.rating} reviews={v.reviews}/> · {L(v.cuisine)} · {v.price} · {L(v.neighbourhood)}</div>
        </div>
      </div>
      <div style={{margin:'14px 20px 0',display:'flex',alignItems:'center',gap:10,padding:'11px 14px',borderRadius:'var(--radius-md)',background:'var(--gold-tint)',border:'1px solid rgba(196,138,75,.35)',color:'var(--gold-dark)',fontSize:13,fontWeight:600}}><Icon name="tag" size={16}/>{t.offer}</div>
      <div style={{padding:'18px 20px 12px',textAlign:ar?'right':'left'}}>
        <AvatarStack people={friends} label={t.friends}/>
        <p style={{fontSize:14,lineHeight:1.7,color:'var(--text-soft)',marginTop:16}}>{t.desc}</p>
      </div>
      <div style={{display:'flex',gap:10,overflowX:'auto',padding:'4px 20px 8px'}}>
        {gallery.map(g=><div key={g} style={{flex:'0 0 auto',width:120}}><Photo image={IMG(g)} height={90} radius={12}/></div>)}
      </div>
      <div style={{padding:'16px 20px 4px',textAlign:ar?'right':'left'}}>
        <div style={{display:'flex',alignItems:'baseline',justifyContent:'space-between'}}>
          <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:19,fontWeight:600,letterSpacing:ar?'0':'-.01em'}}>{t.menu}</div>
          <div style={{fontSize:13,fontWeight:600,color:'var(--gold-dark)',cursor:'pointer'}}>{t.fullMenu}</div>
        </div>
        <div style={{marginTop:6}}>
          {(ar?menu.ar:menu.en).map(([dish,cat,price])=><div key={dish} style={{display:'flex',alignItems:'center',gap:12,padding:'12px 0',borderBottom:'1px solid var(--line)'}}>
            <div style={{flex:1}}><div style={{fontSize:14,fontWeight:600}}>{dish}</div><div style={{fontSize:11,color:'var(--text-faint)',letterSpacing:ar?'0':'.06em',textTransform:ar?'none':'uppercase',marginTop:2}}>{cat}</div></div>
            <div style={{fontSize:14,fontWeight:700,color:'var(--text-soft)',whiteSpace:'nowrap'}}>{price} <span style={{fontSize:11,fontWeight:500,color:'var(--text-faint)'}}>{t.egp}</span></div>
          </div>)}
        </div>
      </div>
      <div style={{padding:'12px 20px 0'}}>
        <MapCard height={140} city={ar?'الزمالك':'ZAMALEK'} pins={[{name:L(v.name),pos:[30.0622,31.2185],time:ar?'9:00':'9:00'}]} center={[30.0622,31.2185]} zoom={15} interactive={false}/>
      </div>
      <div style={{padding:'12px 20px 20px',display:'flex',flexDirection:'column',gap:2}}>
        {t.info.map(([ic,a,b])=><div key={a} style={{display:'flex',alignItems:'center',gap:12,padding:'14px 0',borderBottom:'1px solid var(--line)'}}>
          <span style={{color:'var(--terracotta)',display:'flex'}}><Icon name={ic} size={18}/></span>
          <div style={{flex:1}}><div style={{fontSize:14,fontWeight:600}}>{a}</div><div style={{fontSize:12,fontWeight:600,color:'var(--gold-dark)'}}>{b}</div></div>
        </div>)}
      </div>
    </div>
    <div style={{padding:'14px 20px',borderTop:'1px solid var(--line)',background:'var(--surface-page)',display:'flex',alignItems:'center',gap:14}}>
      <div><div style={{fontSize:12,color:'var(--text-faint)'}}>{t.from}</div><div style={{fontSize:15,fontWeight:700}}>{t.free}</div></div>
      <Button style={{flex:1}} onClick={onBook}>{t.book}</Button>
    </div>
  </div>;
}
function IconBtn({name,active,onClick}){
  return <button onClick={onClick} style={{width:38,height:38,borderRadius:'50%',border:'none',background:'rgba(20,12,8,.5)',backdropFilter:'blur(6px)',color:active?'var(--gold)':'#FDFBF7',cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={name} size={18}/></button>;
}
