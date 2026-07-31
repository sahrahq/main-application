import React from 'react';
import {Button} from '../../components/core/Button';
import {Icon} from '../../components/core/Icon';
import {Photo} from './Photo';
import {mashrabiyaUrl} from '../../components/brand/Mashrabiya';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=900&q=80&auto=format&fit=crop';

const T={en:{over:'Booking confirmed',msg:v=>'We told '+v.name+" you're coming.",date:'Date',time:'Time',guests:'Guests',table:'Table',ref:'Confirmation',cal:'Add to calendar',share:'Invite friends',done:'Done',bookings:'My bookings',city:'Cairo'},
ar:{over:'تم تأكيد الحجز',msg:v=>'بلّغنا '+v.name+' إنك جاي.',date:'التاريخ',time:'الوقت',guests:'الأفراد',table:'الطاولة',ref:'رقم الحجز',cal:'أضف للتقويم',share:'اعزم أصحابك',done:'تمام',bookings:'حجوزاتي',city:'القاهرة'}};
export function ConfirmationScreen({booking={},onDone,onBookings,lang='en'}){
  const ar=lang==='ar';const t=T[lang]||T.en;const L=x=>x&&(typeof x==='object')?(ar?x.ar:x.en):x;
  const dv={en:'Layali Lounge',ar:'ليالي لاونج'};
  const b={venue:{name:dv,image:IMG('1414235077428-338989a2e8c0'),neighbourhood:{en:'Zamalek',ar:'الزمالك'}},party:2,time:ar?'9:00 م':'9:00 PM',day:ar?'الأربع 21':'Wed 21',table:'T4',ref:'SAH-4821',...booking};
  const vname=L(b.venue.name);
  const cell=(label,value)=><div key={label} style={{flex:1,minWidth:0}}>
    <div style={{fontSize:10,letterSpacing:'.1em',textTransform:'uppercase',color:'var(--text-faint)',marginBottom:3}}>{label}</div>
    <div style={{fontSize:15,fontWeight:600,fontFamily:ar?'var(--font-arabic)':'var(--font-latin)'}}>{value}</div>
  </div>;
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',display:'flex',flexDirection:'column',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)',padding:'0 20px 28px',position:'relative',overflow:'hidden'}}>
    <style>{`@keyframes cfRise{0%{opacity:0;transform:translateY(18px)}100%{opacity:1;transform:none}}@keyframes cfSpark{0%{opacity:0;transform:scale(.4) rotate(-30deg)}70%{transform:scale(1.12) rotate(4deg)}100%{opacity:1;transform:none}}`}</style>
    <div style={{flex:1,display:'flex',flexDirection:'column',justifyContent:'center'}}>
      <div style={{textAlign:'center',animation:'cfRise .5s cubic-bezier(.2,.7,.3,1) both'}}>
        <span style={{width:44,height:44,borderRadius:'50%',border:'1.5px solid var(--gold)',color:'var(--gold)',display:'inline-flex',alignItems:'center',justifyContent:'center',animation:'cfSpark .55s .1s cubic-bezier(.34,1.5,.5,1) both'}}><Icon name="spark" size={20}/></span>
        <div style={{fontSize:11,letterSpacing:'.18em',textTransform:'uppercase',color:'var(--gold-dark)',fontWeight:600,marginTop:12}}>{t.over}</div>
        <div style={{fontSize:14,color:'var(--text-soft)',marginTop:6}}>{t.msg({name:vname})}</div>
      </div>
      <div style={{marginTop:22,position:'relative',animation:'cfRise .55s .12s cubic-bezier(.2,.7,.3,1) both'}}>
        <div style={{background:'var(--surface-card)',border:'1px solid var(--line)',borderRadius:'var(--radius-lg)',overflow:'hidden',textAlign:ar?'right':'left'}}>
          <div style={{position:'relative'}}>
            <Photo image={b.venue.image} height={128} gradientOverlay/>
            <div style={{position:'absolute',insetInlineStart:16,bottom:12,insetInlineEnd:16}}>
              <div style={{fontFamily:ar?'var(--font-arabic-display)':'var(--font-display)',fontSize:21,fontWeight:600,color:'#FDFBF7',letterSpacing:ar?'0':'-.01em'}}>{vname}</div>
              <div style={{fontSize:12,color:'rgba(253,251,247,.85)'}}>{L(b.venue.neighbourhood)} · {t.city}</div>
            </div>
          </div>
          <div style={{display:'flex',gap:12,padding:'16px 16px 14px'}}>
            {cell(t.date,b.day)}{cell(t.time,b.time)}{cell(t.guests,b.party)}{cell(t.table,b.table)}
          </div>
          <div style={{position:'relative',height:1,margin:'0 2px',borderTop:'1px dashed var(--line)'}}>
            <span style={{position:'absolute',top:-7,insetInlineStart:-9,width:14,height:14,borderRadius:'50%',background:'var(--surface-page)',border:'1px solid var(--line)'}}></span>
            <span style={{position:'absolute',top:-7,insetInlineEnd:-9,width:14,height:14,borderRadius:'50%',background:'var(--surface-page)',border:'1px solid var(--line)'}}></span>
          </div>
          <div style={{position:'relative',display:'flex',alignItems:'center',justifyContent:'space-between',padding:'12px 16px 14px'}}>
            <div aria-hidden="true" style={{position:'absolute',inset:0,backgroundImage:mashrabiyaUrl('currentColor',34),opacity:.04,pointerEvents:'none'}}></div>
            <div style={{position:'relative'}}>
              <div style={{fontSize:10,letterSpacing:'.1em',textTransform:'uppercase',color:'var(--text-faint)'}}>{t.ref}</div>
              <div style={{fontFamily:'var(--font-mono)',fontSize:13,fontWeight:600,letterSpacing:'.06em',marginTop:2}}>{b.ref}</div>
            </div>
            <Icon name="lantern" size={20} style={{color:'var(--gold)',position:'relative'}}/>
          </div>
        </div>
      </div>
    </div>
    <div style={{animation:'cfRise .55s .22s cubic-bezier(.2,.7,.3,1) both'}}>
      <div style={{display:'flex',gap:12,marginBottom:12}}>
        <Button variant="secondary" style={{flex:1}} icon={<Icon name="calendar-plus" size={16}/>}>{t.cal}</Button>
        <Button variant="secondary" style={{flex:1}} icon={<Icon name="share" size={16}/>}>{t.share}</Button>
      </div>
      <div style={{display:'flex',gap:12}}>
        <Button variant="ghost" style={{flex:1}} onClick={onDone}>{t.done}</Button>
        <Button style={{flex:1}} onClick={onBookings}>{t.bookings}</Button>
      </div>
    </div>
  </div>;
}
