import React from 'react';
import {Icon} from '../../components/core/Icon';
import {Badge} from '../../components/core/Badge';
import {Avatar} from '../../components/social/Avatar';
import {Button} from '../../components/core/Button';
import {Chip} from '../../components/core/Chip';
import {Mashrabiya} from '../../components/brand/Mashrabiya';
const IMG=(id)=>'https://images.unsplash.com/photo-'+id+'?w=200&q=80&auto=format&fit=crop';
const BOOKINGS=[
  {time:'7:30',name:'Mariam El-Sayed',party:2,table:'T4',status:'seated',note:'Anniversary — window table requested',src:IMG('1438761681033-6461ffad8d80')},
  {time:'8:00',name:'Omar Adel',party:4,table:'T9',status:'confirmed',note:'Regular · prefers the terrace',src:IMG('1507003211169-0a1dd7228f2d')},
  {time:'8:30',name:'Nour Hassan',party:2,table:'T2',status:'confirmed',note:'',src:IMG('1544005313-94ddf0286df2')},
  {time:'9:00',name:'Khaled Mostafa',party:6,table:'T12',status:'late',note:'Called — 15 min behind',src:null},
  {time:'9:15',name:'Salma Tarek',party:3,table:'T6',status:'confirmed',note:'Vegetarian menu flagged',src:null},
  {time:'10:00',name:'Youssef Nabil',party:2,table:'T3',status:'pending',note:'',src:null}
];
const TABLES=[['T1',0],['T2',2],['T3',0],['T4',1],['T5',0],['T6',0],['T7',1],['T8',0],['T9',2],['T10',1],['T11',0],['T12',0]]; // 0 free, 1 occupied, 2 reserved-next
const STATUS={seated:['Seated','featured'],confirmed:['Confirmed','default'],late:['Running late','warning'],pending:['Pending','muted']};
export function OperatorDashboard({dark=false,venue='Layali Lounge'}){
  const [filter,setFilter]=React.useState('all');
  const rows=BOOKINGS.filter(b=>filter==='all'||b.status===filter);
  const box={background:'var(--surface-card)',border:'1px solid var(--line)',borderRadius:'var(--radius-lg)'};
  return <div className={dark?'theme-night':''} style={{width:'100%',height:'100%',display:'flex',background:'var(--surface-page)',color:'var(--text-body)',fontFamily:'var(--font-latin)',overflow:'hidden'}}>
    <aside style={{width:200,borderInlineEnd:'1px solid var(--line)',padding:'22px 14px',display:'flex',flexDirection:'column',gap:4,position:'relative'}}>
      <Mashrabiya color="var(--text-body)" opacity={0.03} tile={44} fade/>
      <div style={{display:'flex',alignItems:'center',gap:10,padding:'0 8px 18px'}}>
        <img src={dark?'../../assets/logo.png':'../../assets/logo-terracotta.png'} alt="SAHRA" style={{width:26}}/>
        <div><div style={{fontFamily:'var(--font-display)',fontWeight:600,fontSize:14,letterSpacing:'.14em'}}>SAHRA</div><div style={{fontSize:10,color:'var(--text-faint)',letterSpacing:'.08em'}}>FOR RESTAURANTS</div></div>
      </div>
      {[['calendar','Tonight',true],['map-pin','Floor plan',false],['users','Guests',false],['star','Reviews',false],['mezze','Menu',false]].map(([ic,l,on])=>
        <div key={l} style={{display:'flex',alignItems:'center',gap:10,padding:'9px 10px',borderRadius:'var(--radius-md)',fontSize:13,fontWeight:on?600:500,color:on?'var(--accent)':'var(--text-soft)',background:on?'var(--terracotta-tint)':'transparent',cursor:'pointer'}}><Icon name={ic} size={16}/>{l}</div>)}
    </aside>
    <main style={{flex:1,display:'flex',flexDirection:'column',minWidth:0}}>
      <header style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'18px 24px',borderBottom:'1px solid var(--line)'}}>
        <div>
          <div style={{fontFamily:'var(--font-display)',fontSize:21,fontWeight:600,letterSpacing:'-.01em'}}>{venue} — tonight</div>
          <div style={{fontSize:12,color:'var(--text-faint)'}}>Wednesday 21 · service 6:00 PM – 2:00 AM</div>
        </div>
        <Button size="sm" icon={<Icon name="plus" size={14}/>}>Walk-in</Button>
      </header>
      <div style={{display:'flex',gap:12,padding:'16px 24px 0'}}>
        {[['Covers booked','46'],['Occupancy','72%'],['Seated now','18'],['No-shows','1']].map(([l,v])=>
          <div key={l} style={{...box,flex:1,padding:'12px 16px'}}><div style={{fontSize:11,color:'var(--text-faint)',letterSpacing:'.06em',textTransform:'uppercase'}}>{l}</div><div style={{fontFamily:'var(--font-display)',fontSize:24,fontWeight:600,marginTop:2}}>{v}</div></div>)}
      </div>
      <div style={{display:'flex',gap:8,padding:'14px 24px 10px'}}>
        {[['all','All'],['confirmed','Confirmed'],['seated','Seated'],['late','Late'],['pending','Pending']].map(([id,l])=>
          <Chip key={id} selected={filter===id} onClick={()=>setFilter(id)}>{l}</Chip>)}
      </div>
      <div style={{flex:1,overflowY:'auto',padding:'0 24px 20px',display:'flex',flexDirection:'column',gap:8}}>
        {rows.map(b=><div key={b.name} style={{...box,display:'flex',alignItems:'center',gap:14,padding:'12px 16px'}}>
          <div style={{fontFamily:'var(--font-display)',fontSize:16,fontWeight:600,width:44}}>{b.time}</div>
          <Avatar name={b.name} src={b.src} size={36}/>
          <div style={{flex:1,minWidth:0}}>
            <div style={{fontSize:14,fontWeight:600}}>{b.name}</div>
            {b.note&&<div style={{fontSize:12,color:'var(--text-faint)',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{b.note}</div>}
          </div>
          <div style={{display:'flex',alignItems:'center',gap:6,fontSize:13,color:'var(--text-soft)'}}><Icon name="users" size={14}/>{b.party}</div>
          <div style={{fontSize:13,color:'var(--text-soft)',width:34}}>{b.table}</div>
          <Badge variant={STATUS[b.status][1]}>{STATUS[b.status][0]}</Badge>
        </div>)}
      </div>
    </main>
    <aside style={{width:230,borderInlineStart:'1px solid var(--line)',padding:'20px 18px',display:'flex',flexDirection:'column',gap:14}}>
      <div style={{fontSize:12,fontWeight:600,letterSpacing:'.08em',textTransform:'uppercase',color:'var(--text-faint)'}}>Floor · main room</div>
      <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:10}}>
        {TABLES.map(([t,s])=><div key={t} style={{aspectRatio:'1',borderRadius:'var(--radius-md)',display:'flex',alignItems:'center',justifyContent:'center',fontSize:12,fontWeight:600,border:'1px solid '+(s===1?'var(--terracotta)':s===2?'var(--gold-dark)':'var(--line)'),background:s===1?'var(--terracotta-tint)':s===2?'var(--gold-tint)':'var(--surface-card)',color:s===1?'var(--terracotta-dark)':s===2?'var(--gold-dark)':'var(--text-faint)'}}>{t}</div>)}
      </div>
      <div style={{display:'flex',gap:12,fontSize:11,color:'var(--text-faint)',flexWrap:'wrap'}}>
        {[['var(--terracotta)','Seated'],['var(--gold-dark)','Reserved next'],['var(--line)','Free']].map(([c,l])=><span key={l} style={{display:'flex',alignItems:'center',gap:5}}><span style={{width:9,height:9,borderRadius:3,border:'1px solid '+c,display:'inline-block'}}></span>{l}</span>)}
      </div>
    </aside>
  </div>;
}
