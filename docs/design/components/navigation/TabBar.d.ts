export interface TabBarProps{items?:{id:string;label:string;icon:string}[];active?:string;onChange?:(id:string)=>void;style?:React.CSSProperties}
export function TabBar(props:TabBarProps):JSX.Element;