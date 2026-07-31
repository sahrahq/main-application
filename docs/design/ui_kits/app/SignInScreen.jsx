import React from 'react';
import {Button} from '../../components/core/Button';
import {Input} from '../../components/core/Input';
import {Icon} from '../../components/core/Icon';
import {Mashrabiya} from '../../components/brand/Mashrabiya';
const T={
  en:{l1:'Find',l2:'the vibe',l3:'for tonight',signin:'SIGN IN',signup:'SIGN UP',phone:'Phone number',phoneP:'+20 100 000 0000',pass:'Password',name:'Name',nameP:'Your name',cont:'Continue',forgot:'Forgot password?',fb:'Facebook',g:'Google',or:'or'},
  ar:{l1:'\u0627\u0639\u062b\u0631 \u0639\u0644\u0649',l2:'\u0627\u0644\u0623\u062c\u0648\u0627\u0621',l3:'\u0627\u0644\u0645\u0646\u0627\u0633\u0628\u0629 \u0644\u0644\u064a\u0644\u062a\u0643',signin:'\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644',signup:'\u062d\u0633\u0627\u0628 \u062c\u062f\u064a\u062f',phone:'\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641',phoneP:'+20 100 000 0000',pass:'\u0643\u0644\u0645\u0629 \u0627\u0644\u0633\u0631',name:'\u0627\u0644\u0627\u0633\u0645',nameP:'\u0627\u0633\u0645\u0643',cont:'\u0645\u062a\u0627\u0628\u0639\u0629',forgot:'\u0646\u0633\u064a\u062a \u0643\u0644\u0645\u0629 \u0627\u0644\u0633\u0631\u061f',fb:'\u0641\u064a\u0633\u0628\u0648\u0643',g:'\u062c\u0648\u062c\u0644',or:'\u0623\u0648'}
};
export function SignInScreen({onContinue,onClose,lang='en',dark=true,logoSrc}){
  const src=logoSrc||(dark?'../../assets/logo.png':'../../assets/logo-terracotta.png');
  const [tab,setTab]=React.useState('in');
  const ar=lang==='ar';const t=T[lang]||T.en;
  const social={flex:1,display:'flex',alignItems:'center',justifyContent:'center',gap:8,padding:'12px 0',borderRadius:'var(--radius-md)',border:'1px solid var(--line)',background:'var(--surface-card)',color:'var(--text-body)',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)',fontSize:13,fontWeight:600,cursor:'pointer'};
  return <div dir={ar?'rtl':'ltr'} style={{height:'100%',position:'relative',display:'flex',flexDirection:'column',padding:'20px 24px 32px',boxSizing:'border-box',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)',textAlign:ar?'right':'left',overflow:'hidden'}}>
    <Mashrabiya color="var(--text-body)" opacity={dark?0.05:0.035} tile={46} fade/>
    <div style={{position:'relative',display:'flex',justifyContent:'space-between',alignItems:'center'}}>
      <img src={src} alt="SAHRA" style={{width:34}}/>
      <button onClick={onClose} style={{background:'none',border:'none',color:'var(--text-faint)',cursor:'pointer',display:'flex',padding:4}}><Icon name="x" size={20}/></button>
    </div>
    <div style={{position:'relative',fontFamily:ar?'var(--font-arabic)':'var(--font-display)',fontSize:ar?30:38,lineHeight:ar?1.4:1.12,marginTop:26,letterSpacing:ar?'0':'-.01em'}}>
      <div style={{fontWeight:ar?600:400,color:'var(--text-body)'}}>{t.l1}</div><div style={{fontWeight:700,color:'var(--terracotta)',fontStyle:ar?'normal':'italic'}}>{t.l2}</div><div style={{fontWeight:600,color:'var(--text-body)'}}>{t.l3}</div>
    </div>
    <div style={{position:'relative',display:'flex',gap:24,marginTop:26}}>
      {[['in',t.signin],['up',t.signup]].map(([id,l])=><button key={id} onClick={()=>setTab(id)} style={{background:'none',border:'none',cursor:'pointer',padding:'0 0 8px',color:tab===id?'var(--text-body)':'var(--text-faint)',borderBottom:tab===id?'2px solid var(--terracotta)':'2px solid transparent',fontFamily:ar?'var(--font-arabic)':'var(--font-latin)',fontSize:13,fontWeight:700,letterSpacing:ar?'0':'.1em'}}>{l}</button>)}
    </div>
    <div style={{position:'relative',display:'flex',gap:12,marginTop:22}}>
      <button style={social}><Icon name="facebook" size={17} style={{color:'#1877F2'}}/>{t.fb}</button>
      <button style={social}><span style={{fontWeight:800,color:'#EA4335'}}>G</span>{t.g}</button>
    </div>
    <div style={{position:'relative',display:'flex',alignItems:'center',gap:12,margin:'20px 0'}}>
      <span style={{flex:1,height:1,background:'var(--line)'}}></span><span style={{fontSize:12,color:'var(--text-faint)'}}>{t.or}</span><span style={{flex:1,height:1,background:'var(--line)'}}></span>
    </div>
    <div style={{position:'relative',display:'flex',flexDirection:'column',gap:18}}>
      <Input variant="line" label={t.phone} placeholder={t.phoneP}/>
      <Input variant="line" label={t.pass} type="password" defaultValue="password"/>
      {tab==='up'&&<Input variant="line" label={t.name} placeholder={t.nameP}/>}
    </div>
    <div style={{flex:1}}></div>
    <Button onClick={onContinue} style={{position:'relative',width:'100%',letterSpacing:ar?'0':'.1em',fontSize:14}}>{t.cont}</Button>
    <div style={{position:'relative',textAlign:'center',marginTop:16,fontSize:13,fontStyle:ar?'normal':'italic',color:'var(--text-soft)'}}>{t.forgot}</div>
  </div>;
}