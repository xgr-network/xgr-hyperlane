import {manifestRoute,connectWallet,switchChain,quoteBridge,readAllowance,approveAmount,sendBridge,waitReceipt,messageIdFromReceipt,isDelivered,formatUnits,shorten} from "./protocol.mjs";
const el=document.querySelector("#app"),connect=document.querySelector("#connect");
const state={catalog:null,account:null,quote:null,quoteKey:null,transfer:null,busy:false};
const names={xgrchain:"XGRChain",base:"Base",polygon:"Polygon",arbitrum:"Arbitrum"};
const routeName=r=>names[r.sourceChain]+" → "+names[r.destinationChain];
const x=raw=>String(raw??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const asset=()=>state.catalog.assets.XGR;
const route=r=>manifestRoute(state.catalog,asset(),r);
const routes=()=>asset().routes.routes;
const active=()=>routes().filter(r=>route(r.name).allowed).length;
const path=()=>decodeURIComponent(location.pathname).replace(/\/+$/,"")||"/";
const btn=(url,label,alt=false)=>'<a data-nav href="'+url+'" class="btn'+(alt?" alt":"")+'">'+label+'</a>';
const tag=r=>'<span class="tag">'+(route(r.name).allowed?"Verified":"Pending governance")+'</span>';
const fmt=(n,dec=18)=>formatUnits(n,dec,10);
const note=t=>'<div class="notice">'+t+'</div>';
function overview(){
 return '<div class="eyebrow">XGR EVM Token Alliance</div><h1>One ecosystem.<br>Every connected token.</h1>'+
 '<p class="lead">Discover assets, explore networks and move tokens through the quorum-governed XGRChain hub. Every token page includes its own bridge.</p>'+
 '<div class="actions">'+btn("/token/xgr","Explore XGR token")+btn("/markets","Browse markets",true)+'</div>'+
 '<div class="cards">'+[
 ["Assets",Object.keys(state.catalog.assets).length,"Published catalog"],
 ["Active routes",active(),"Quorum-approved, verified"],
 ["Bridged value","—","Verified indexer pending"],
 ["24h volume","—","Verified indexer pending"]
 ].map(v=>'<div class="card"><small>'+v[0]+'</small><strong>'+v[1]+'</strong><small>'+v[2]+'</small></div>').join("")+'</div>'+
 '<section class="section"><div class="eyebrow">Open Interchain Infrastructure</div><h2>XGRChain connects the network</h2><p class="muted">Base ↔ XGRChain ↔ Polygon / Arbitrum. Spoke-to-spoke transfers are two independent hops via XGRChain; no gasless forwarder is deployed.</p><div class="card"><h3>Configured routes</h3>'+routes().map(r=>'<div class="pair"><span>'+routeName(r)+'</span>'+tag(r)+'</div>').join("")+'</div></section>'+
 '<section class="section"><h2>Explore token assets</h2><div class="card token-link"><span class="logo">X</span><div><h3>XGR / wXGR</h3><p class="muted">Native on XGRChain, planned synthetic representations on three EVM chains</p>'+btn("/token/xgr","Open token and bridge")+'</div></div></section>'+
 '<section class="section"><h2>Open to projects</h2><p class="lead">Alliance applications and standard listing are free. Token integration and route activation require independent validator-quorum approval.</p>'+btn("/join","Join the Alliance")+'</section>';
}
function markets(){
 return '<div class="eyebrow">Discovery</div><h1>Token markets</h1><p class="lead">Browse bridgeable and planned assets. Trading data will be added using clearly identified, timestamped sources.</p>'+
 '<label class="field" for="search">Find a token</label><input id="search" placeholder="Search by symbol or token name">'+
 '<div class="card section" style="overflow:auto"><table class="table"><thead><tr><th>Token</th><th>Price</th><th>Market cap</th><th>24h trading volume</th><th>Verified routes</th></tr></thead><tbody id="market-row"><tr><td><a href="/token/xgr" data-nav>XGR / wXGR</a></td><td>—</td><td>—</td><td>—</td><td>'+active()+' / '+routes().length+'</td></tr></tbody></table></div>'+
 '<p class="muted">Unverified market data are never inferred from bridge activity or token supply.</p>';
}
function token(){
 return '<div class="columns"><article><a href="/markets" data-nav class="muted">← All tokens</a>'+
 '<div class="token-link section"><div class="logo">X</div><div><div class="eyebrow">Canonical network · XGRChain</div><h1>XGR / wXGR</h1><span class="tag">XETA v3.1.4 · Pre-deployment</span></div></div>'+
 '<div class="card"><h2>Asset profile</h2><p class="muted">Native XGR on XGRChain (1643). wXGR representations on Base, Polygon and Arbitrum become available following verified activation.</p>'+
 '<div class="pair"><span>Decimals</span><b>'+asset().metadata.decimals+'</b></div><div class="pair"><span>Active routes</span><b>'+active()+' / '+routes().length+'</b></div><div class="pair"><span>Market data</span><b>Awaiting verified feed</b></div></div>'+
 '<section class="section"><h2>Available networks</h2><div class="routes">'+routes().map(r=>'<div class="route"><strong>'+routeName(r)+'</strong><div style="margin-top:10px">'+tag(r)+'</div></div>').join("")+'</div></section>'+
 '<section class="section"><h2>Validator governance</h2><p class="muted">Transfers require an active route approved by the validator quorum, a verified source Gateway, and independent Mailbox delivery on the destination chain.</p></section></article>'+
 '<aside class="card"><div class="eyebrow">Bridge XGR</div><h2>Transfer this token</h2><p class="muted">Select the source and destination. Quotes use the source Gateway; approvals are granted to the Gateway, not a Warp router.</p>'+
 '<label class="field" for="route">Route</label><select id="route">'+routes().map(r=>'<option value="'+r.name+'">'+routeName(r)+' · '+(route(r.name).allowed?"verified":"planned")+'</option>').join("")+'</select>'+
 '<label class="field" for="amount">Amount (XGR)</label><input id="amount" inputmode="decimal" placeholder="0.0" autocomplete="off">'+
 '<div id="route-note">'+note("Route not activated. No unverified contracts can receive funds.")+'</div>'+
 '<div class="note section" id="quote">No live quote available.</div>'+
 '<button class="wide alt" id="quote-btn" disabled>Request Gateway quote</button><button class="wide" id="bridge-btn" disabled>Bridge token</button>'+
 '<p class="status" id="status">Connect an EVM wallet to begin.</p>'+
 '<div id="transfer" class="hidden"><h3>Transfer status</h3><p class="status" id="message-id"></p><button class="wide alt" id="check-delivery">Check destination delivery</button><p class="status" id="delivery"></p></div></aside></div>';
}
function join(){
 return '<div class="eyebrow">Join the XGR EVM Token Alliance</div><h1>Bring your token to more networks.</h1>'+
 '<p class="lead">Applications, review, standard integration and project listing are free. Export an application draft for review; this UI does not claim to submit it or activate governance.</p>'+
 '<div class="columns"><form id="application" class="card"><h2>Project application</h2>'+
 '<label class="field">Project name</label><input id="project" required maxlength="80"><label class="field">Token symbol</label><input id="symbol" required maxlength="20">'+
 '<label class="field">Project website</label><input id="website" required type="url" placeholder="https://">'+
 '<label class="field">Canonical chain</label><select id="canonical">'+Object.keys(state.catalog.chains).map(c=>'<option value="'+c+'">'+names[c]+'</option>').join("")+'</select>'+
 '<label class="field">Canonical token address</label><input id="address" required pattern="0x[0-9A-Fa-f]{40}" placeholder="0x…">'+
 '<label class="field">Token decimals</label><input id="decimals" type="number" min="0" max="36" value="18" required>'+
 '<label class="field">Target networks (Ctrl/Cmd for multiple)</label><select id="targets" multiple size="4">'+Object.keys(state.catalog.chains).map(c=>'<option value="'+c+'">'+names[c]+'</option>').join("")+'</select>'+
 '<label class="field">Project contact email</label><input id="email" type="email" required>'+
 '<p class="muted">Proof of wallet or multisig authorization will be required during review. Never submit private keys.</p><label><input style="width:auto;display:inline" id="ack" type="checkbox" required> I confirm I represent this project</label>'+
 '<button class="wide" type="submit">Export application JSON</button><p class="status" id="form-status"></p></form>'+
 '<div class="card"><h2>From token to alliance</h2><p class="muted">01 · Submit your token specification</p><p class="muted">02 · Token contract and project authorization verification</p><p class="muted">03 · Validator quorum route governance</p><p class="muted">04 · Verified deployment and live token page</p>'+
 '<div class="notice">This form saves a local draft only. It does not send information to a backend, request a wallet signature, or grant token onboarding approval.</div></div></div>';
}
function routesPage(){return '<div class="eyebrow">Research & development</div><h1>Route Finder</h1><p class="lead">Future graph search across DEX swaps and XETA bridge hops. Route quotes, non-atomic recovery, gas sponsorship and liquidity indexing are not live.</p>'+btn("/token/xgr","Explore initial token");}
function reset(){state.quote=null;state.quoteKey=null;const q=document.querySelector("#quote");if(q)q.textContent="Request a live Gateway quote before you bridge.";controls();}
function current(){return document.querySelector("#route")?.value;}
function key(){return current()+"|"+document.querySelector("#amount")?.value+"|"+state.account;}
function controls(){
 const q=document.querySelector("#quote-btn"),b=document.querySelector("#bridge-btn");
 if(!q)return;
 const a=route(current()).allowed;
 q.disabled=state.busy||!state.account||!a;
 b.disabled=state.busy||!a||!state.account||!state.quote||state.quoteKey!==key();
 const n=document.querySelector("#route-note");
 if(n)n.innerHTML=a?'<div class="note">Active inventory: on-chain route validation still required before quoting.</div>':note("Route not validator-activated and independently verified. Transfers are disabled.");
}
function status(s){const e=document.querySelector("#status");if(e)e.textContent=s;}
async function action(fn){
 if(state.busy)return;
 state.busy=true;controls();
 try{await fn();}catch(e){status(e.message||"Wallet action failed");alert(e.message||"Wallet action failed");}
 finally{state.busy=false;controls();}
}
async function requestQuote(){
 await action(async()=>{
  if(!state.account)throw Error("Connect a wallet first");
  const r={...route(current()),assetCanonicalChain:asset().metadata.canonical.chain};
  if(!r.allowed)throw Error("Route is not activated");
  await switchChain(globalThis.ethereum,r.src);
  status("Reading canonical registry and live Gateway fees…");
  const q=await quoteBridge(globalThis.ethereum,r,state.account,document.querySelector("#amount").value,asset().metadata.decimals);
  state.quote=q;state.quoteKey=key();
  document.querySelector("#quote").innerHTML=
    '<div class="pair"><span>Validator fee</span><b>'+fmt(q.validatorFeeWei)+' '+r.src.nativeCurrency.symbol+'</b></div>'+
    '<div class="pair"><span>Router/native amount</span><b>'+fmt(q.routerNativeValueWei)+' '+r.src.nativeCurrency.symbol+'</b></div>'+
    '<div class="pair"><span>Total native value</span><b>'+fmt(q.totalNativeValueWei)+' '+r.src.nativeCurrency.symbol+'</b></div>'+
    '<div class="pair"><span>ERC-20 principal</span><b>'+fmt(q.tokenAmount,asset().metadata.decimals)+'</b></div>';
  status("Live quote received. Fees can change before the transaction is signed.");
 });
}
async function bridge(){
 await action(async()=>{
  if(!state.quote||state.quoteKey!==key())throw Error("Request a fresh quote");
  const r={...route(current()),assetCanonicalChain:asset().metadata.canonical.chain},old=state.quote;
  await switchChain(globalThis.ethereum,r.src);
  const fresh=await quoteBridge(globalThis.ethereum,r,state.account,document.querySelector("#amount").value,asset().metadata.decimals);
  if(fresh.totalNativeValueWei!==old.totalNativeValueWei)throw Error("Gateway quote has changed. Please request a fresh quote.");
  if(fresh.tokenAmount>0n){
   const allowance=await readAllowance(globalThis.ethereum,fresh.token,state.account,r.deployed.gateway);
   if(allowance<fresh.tokenAmount){
    if(!confirm("Approve the exact token amount to the canonical XETA Gateway?"))return;
    const approval=await approveAmount(globalThis.ethereum,fresh.token,r.deployed.gateway,fresh.tokenAmount,state.account);
    status("Waiting for ERC-20 allowance approval receipt…");
    await waitReceipt(globalThis.ethereum,approval);
    const newAllowance=await readAllowance(globalThis.ethereum,fresh.token,state.account,r.deployed.gateway);
    if(newAllowance<fresh.tokenAmount)throw Error("Token allowance remains insufficient");
   }
  }
  const recheck=await quoteBridge(globalThis.ethereum,r,state.account,document.querySelector("#amount").value,asset().metadata.decimals);
  if(recheck.totalNativeValueWei!==fresh.totalNativeValueWei)throw Error("Fees changed before bridging. Request a new quote.");
  if(!confirm("Submit XETA Gateway transfer? Tokens will be locked or burned; destination settlement is separate."))return;
  const tx=await sendBridge(globalThis.ethereum,r,state.account,recheck);
  state.quote=null;state.quoteKey=null;status("Source transaction submitted: "+tx);
  const receipt=await waitReceipt(globalThis.ethereum,tx);
  const messageId=messageIdFromReceipt(receipt,r);
  state.transfer={r,messageId,tx};
  document.querySelector("#transfer").classList.remove("hidden");
  document.querySelector("#message-id").textContent="Source confirmed · Transaction "+tx+" · Message "+messageId;
  document.querySelector("#delivery").textContent="Destination delivery not yet verified. Never bridge a second time to retry delivery.";
  status("Source transaction confirmed. Destination settlement pending.");
 });
}
async function delivery(){
 await action(async()=>{
  if(!state.transfer)throw Error("No original message to check");
  const {r,messageId}=state.transfer;
  await switchChain(globalThis.ethereum,r.dst);
  const delivered=await isDelivered(globalThis.ethereum,r,messageId);
  document.querySelector("#delivery").textContent=delivered?"Verified as delivered in destination Mailbox. Transfer complete.":"Not yet delivered. Use original message ID for relayer-independent recovery; do not rebridge.";
 });
}
function application(e){
 e.preventDefault();
 if(!e.target.reportValidity())return;
 const targets=[...document.querySelector("#targets").selectedOptions].map(o=>o.value);
 if(!targets.length){document.querySelector("#form-status").textContent="Select at least one target network.";return;}
 const data={schemaVersion:1,kind:"xeta-alliance-application-draft",status:"unsubmitted",
 project:document.querySelector("#project").value,symbol:document.querySelector("#symbol").value,
 website:document.querySelector("#website").value,canonicalChain:document.querySelector("#canonical").value,
 canonicalAddress:document.querySelector("#address").value,decimals:Number(document.querySelector("#decimals").value),
 targetNetworks:targets,contact:document.querySelector("#email").value,
 authorizationProof:"pending",governance:"not-approved"};
 const blob=new Blob([JSON.stringify(data,null,2)+"\n"],{type:"application/json"}),url=URL.createObjectURL(blob);
 const a=document.createElement("a");a.href=url;a.download="xeta-token-application.json";a.click();
 URL.revokeObjectURL(url);
 document.querySelector("#form-status").textContent="Downloaded locally; nothing submitted to XETA.";
}
function render(){
 const p=path();
 el.innerHTML=p==="/"?overview():p==="/markets"?markets():(p==="/token/xgr"||p==="/xgr")?token():p==="/join"?join():p==="/routes"?routesPage():'<h1>Not found</h1>'+btn("/markets","Browse tokens");
 document.querySelector("#route")?.addEventListener("change",reset);
 document.querySelector("#amount")?.addEventListener("input",reset);
 document.querySelector("#quote-btn")?.addEventListener("click",requestQuote);
 document.querySelector("#bridge-btn")?.addEventListener("click",bridge);
 document.querySelector("#check-delivery")?.addEventListener("click",delivery);
 document.querySelector("#application")?.addEventListener("submit",application);
 document.querySelector("#search")?.addEventListener("input",e=>document.querySelector("#market-row").style.display=/xgr|wrapped|^$/i.test(e.target.value)?"":"none");
 controls();
}
connect.addEventListener("click",async()=>{
 if(!globalThis.ethereum){alert("An injected EIP-1193 EVM wallet is required.");return;}
 try{state.account=await connectWallet(globalThis.ethereum);connect.textContent=shorten(state.account);reset();}catch(e){alert(e.message);}
});
if(globalThis.ethereum?.on){
 globalThis.ethereum.on("accountsChanged",()=>{state.account=null;connect.textContent="Connect Wallet";reset();});
 globalThis.ethereum.on("chainChanged",reset);
}
document.addEventListener("click",e=>{
 const a=e.target.closest("a[data-nav]");
 if(!a||e.metaKey||e.ctrlKey||e.shiftKey||e.altKey)return;
 e.preventDefault();history.pushState(null,"",a.pathname);render();scrollTo(0,0);
});
window.addEventListener("popstate",render);
try{
 const res=await fetch("/catalog.json",{cache:"no-store"});
 if(!res.ok)throw Error("Manifest unavailable");
 state.catalog=await res.json();
 if(!state.catalog.assets?.XGR?.routes||!state.catalog.infrastructure?.xgrchain)throw Error("Invalid manifest");
 render();
}catch(e){el.innerHTML="<h1>XETA inventory unavailable</h1><p>"+x(e.message)+"</p><p>Bridging is disabled until a verified manifest is available.</p>";}
