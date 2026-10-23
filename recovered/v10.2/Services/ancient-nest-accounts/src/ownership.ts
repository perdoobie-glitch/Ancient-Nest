export interface OwnershipEnv { STEAM_APP_ID?:string; STEAM_PUBLISHER_KEY?:string; REQUIRE_OWNERSHIP?:string; }
export type Entitlement = {provider:'steam';status:'not_configured'|'verified'|'not_owned'|'unavailable';has_access:boolean;checked_at:number|null;permanent?:boolean;message:string};
// Store adapters must verify ownership on the server. Steam identity alone grants nothing.
export async function ownership(env:OwnershipEnv,steamId:string):Promise<Entitlement> {
 const base={provider:'steam' as const,has_access:false,checked_at:null};
 if(!/^[1-9][0-9]{0,9}$/.test(env.STEAM_APP_ID||'')||Number(env.STEAM_APP_ID)>4294967295||!env.STEAM_PUBLISHER_KEY)return {...base,status:'not_configured',message:'Steam ownership checks require the game App ID and a server-side publisher key.'};
 const url=new URL('https://partner.steam-api.com/ISteamUser/CheckAppOwnership/v4/');
 url.searchParams.set('key',env.STEAM_PUBLISHER_KEY);url.searchParams.set('steamid',steamId);url.searchParams.set('appid',env.STEAM_APP_ID!);
 try {
  const response=await fetch(url,{redirect:'manual',signal:AbortSignal.timeout(6000)});
  if(!response.ok)throw Error('provider_unavailable');
  const data=await response.json() as {appownership?:{ownsapp?:boolean;permanent?:boolean;usercanceled?:boolean}};
  const value=data.appownership;if(!value||typeof value.ownsapp!=='boolean')throw Error('invalid_provider_response');
  const granted=value.ownsapp===true&&value.usercanceled!==true;
  return {...base,status:granted?'verified':'not_owned',has_access:granted,checked_at:Math.floor(Date.now()/1000),permanent:value.permanent===true,message:granted?'Steam reports an active game license. This does not establish a cash transaction.':'Steam reports no active game license.'};
 }catch{return {...base,status:'unavailable',message:'Steam ownership could not be checked. No access was granted.'};}
}
