/* VSS Help Assistant — curated website guide and navigation helper (no external AI/API). */
(()=> {
 if(document.getElementById('vss-help-widget'))return;
 const style=document.createElement('style');
 style.textContent=`
 #vss-help-widget{position:fixed;right:20px;bottom:112px;z-index:9999;font-family:inherit;color:#182438}
 #vss-help-launch{width:58px;height:58px;border:0;border-radius:50%;background:linear-gradient(145deg,#b88a35,#f3d98e);color:#30200a;font-size:25px;box-shadow:0 10px 28px #1b253044;cursor:pointer}
 #vss-help-panel{display:none;position:absolute;right:0;bottom:70px;width:min(360px,calc(100vw - 30px));height:min(510px,70vh);background:#fff;border:1px solid #e5e8ed;border-radius:20px;box-shadow:0 20px 60px #10182733;overflow:hidden;flex-direction:column}
 #vss-help-panel.open{display:flex}
 #vss-help-head{padding:15px 16px;background:linear-gradient(120deg,#172b43,#263d56);color:#fff;display:flex;justify-content:space-between;align-items:center}
 #vss-help-head strong{display:block;font-size:14px}#vss-help-head small{font-size:10px;opacity:.78}
 #vss-help-close{border:0;background:#ffffff20;color:#fff;border-radius:9px;padding:6px 10px;font-size:18px;cursor:pointer}
 #vss-help-messages{padding:14px;overflow:auto;display:flex;flex-direction:column;gap:10px;flex:1;background:#f7f8fa}
 .vss-help-msg{max-width:88%;padding:10px 12px;border-radius:13px;font-size:12px;line-height:1.5;white-space:pre-wrap;overflow-wrap:anywhere}
 .vss-help-msg.bot{align-self:flex-start;background:#fff;border:1px solid #e8ebef;color:#263449;border-bottom-left-radius:4px}
 .vss-help-msg.user{align-self:flex-end;background:#20364f;color:#fff;border-bottom-right-radius:4px}
 .vss-help-links{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}
 .vss-help-links a,.vss-help-links button{font:inherit;font-size:11px;font-weight:750;text-decoration:none;color:#8a5d13;background:#fff8e7;border:1px solid #eedaa9;border-radius:999px;padding:7px 10px;cursor:pointer}
 #vss-help-quick{display:flex;gap:6px;overflow-x:auto;padding:9px 12px;border-top:1px solid #edf0f3;background:#fff}
 #vss-help-quick button{white-space:nowrap;border:1px solid #e2e6eb;background:#fff;border-radius:999px;padding:7px 10px;font:inherit;font-size:10px;cursor:pointer;color:#263449}
 #vss-help-form{display:flex;gap:7px;padding:10px;border-top:1px solid #edf0f3;background:#fff}
 #vss-help-input{min-width:0;flex:1;border:1px solid #dfe4ea;border-radius:11px;padding:11px;font:inherit;font-size:12px;outline:none}
 #vss-help-send{border:0;border-radius:11px;background:#a71928;color:#fff;padding:0 14px;font-weight:800;cursor:pointer}
 @media(max-width:600px){#vss-help-widget{right:12px;bottom:100px}#vss-help-launch{width:54px;height:54px}}
 `;
 document.head.appendChild(style);
 const root=document.createElement('div');root.id='vss-help-widget';
 root.innerHTML='<button id="vss-help-launch" aria-label="Open VSS help assistant" title="VSS Help">✦</button><section id="vss-help-panel" aria-label="VSS help assistant"><header id="vss-help-head"><div><strong>VSS Help Assistant</strong><small>Website guide · Quick answers</small></div><button id="vss-help-close" aria-label="Close help">×</button></header><div id="vss-help-messages" aria-live="polite"></div><div id="vss-help-quick"><button data-q="What is VSS?">About VSS</button><button data-q="How do I register?">Register</button><button data-q="How do I access my ID?">My ID</button><button data-q="How do I contact VSS?">Contact</button></div><form id="vss-help-form"><input id="vss-help-input" placeholder="Ask about VSS or this website…" autocomplete="off" maxlength="220"><button id="vss-help-send">Send</button></form></section>';
 document.body.appendChild(root);
 const panel=root.querySelector('#vss-help-panel'),messages=root.querySelector('#vss-help-messages'),input=root.querySelector('#vss-help-input');
 const links=[['Home','index.html#home'],['About VSS','index.html#about'],['What we do','index.html#work'],['Events','index.html#events'],['Team','index.html#team'],['Contact','index.html#contact'],['Member portal','membership.html#memberAccessPanel'],['Register','membership.html'],['Login','login.html']];
 const add=(text,who='bot',items=[])=>{
  const el=document.createElement('div');el.className='vss-help-msg '+who;el.textContent=text;
  if(items.length){const row=document.createElement('div');row.className='vss-help-links';items.forEach(([label,url])=>{const a=document.createElement('a');a.textContent=label;a.href=url;row.appendChild(a);});el.appendChild(row);}
  messages.appendChild(el);messages.scrollTop=messages.scrollHeight;
 };
 const answer=q=>{
  const x=q.toLowerCase();
  if(/what is vss|about vss|meaning|full form|vidyarthi/.test(x))return ['VSS means Vidyarthi Seva Sangathan — an independent, unofficial, student-led community. It connects students through peer guidance, volunteering, collaboration and student initiatives. It is not an official institute or university body.',[['About VSS','index.html#about'],['Our work','index.html#work']]];
  if(/register|join|new member|membership/.test(x))return ['You can register through the VSS membership page. Complete the form and upload a clear JPG, PNG or WEBP photo. Your VSS membership ID is generated after successful registration.',[['Register as a member','membership.html']]];
  if(/id card|my id|retrieve|forgot.*id|download/.test(x))return ['Already registered? Open the member portal and enter your VSS membership number with the email address registered to that ID. You can view and download your digital card there.',[['Open member portal','membership.html#memberAccessPanel']]];
  if(/premium|gold|core member/.test(x))return ['Premium gold ID cards are reserved for core members and require administrator approval. Sign in to the member portal and submit a premium-card request with your core-team designation. The card appears only after approval.',[['Member portal','membership.html#memberAccessPanel']]];
  if(/login|sign in|portal|password/.test(x))return ['Choose the member portal for your VSS ID and registered email. Administrator access is separate and is available from the login page.',[['Login options','login.html'],['Member portal','membership.html#memberAccessPanel']]];
  if(/event|activity|programme|program/.test(x))return ['Explore VSS events and activities on the homepage. Check the latest published notices and event details in the member portal too.',[['Events & gallery','index.html#events'],['Member portal','membership.html#memberAccessPanel']]];
  if(/team|core|coordinator|volunteer/.test(x))return ['Visit the VSS team section to learn about the student leadership and core team. Volunteer opportunities may also be shared through VSS announcements.',[['Meet the team','index.html#team'],['Notices','membership.html#memberAccessPanel']]];
  if(/contact|email|help|support/.test(x))return ['For VSS enquiries, use the contact section on the website. For account-specific help, include your VSS ID when contacting the team; never share your password or OTP.',[['Contact VSS','index.html#contact']]];
  if(/where|navigate|go to|find/.test(x)){
   const found=links.filter(([label,url])=>x.includes(label.toLowerCase())||x.includes(url.split('#')[1]||'___'));
   if(found.length)return ['Here is the website section you may be looking for:',found.slice(0,4)];
  }
  return ['I can help you navigate VSS and explain membership, ID cards, core-member premium cards, events, the team and contact information. Try one of the quick topics below.',[['About VSS','index.html#about'],['Register','membership.html'],['Member portal','membership.html#memberAccessPanel'],['Contact','index.html#contact']]];
 };
 const send=q=>{q=(q||'').trim();if(!q)return;add(q,'user');const [reply,items]=answer(q);add(reply,'bot',items);};
 root.querySelector('#vss-help-launch').addEventListener('click',()=>{panel.classList.toggle('open');if(panel.classList.contains('open')&&!messages.children.length)add('Hello! I’m the VSS Help Assistant. Ask me about VSS or tell me which page you want to open.');});
 root.querySelector('#vss-help-close').addEventListener('click',()=>panel.classList.remove('open'));
 root.querySelector('#vss-help-form').addEventListener('submit',e=>{e.preventDefault();send(input.value);input.value='';});
 root.querySelectorAll('[data-q]').forEach(b=>b.addEventListener('click',()=>send(b.dataset.q)));
})();