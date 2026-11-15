'use strict';
(async () => {
  const WEB = '/mochi/';
  const APK = '/downloads/Mochii-1.4.10-2047.apk';
  const paths = {
    book:'M4 3h6a3 3 0 0 1 3 3v15a4 4 0 0 0-4-3H4zM20 3h-4a3 3 0 0 0-3 3v15a4 4 0 0 1 4-3h3z',
    target:'M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20M12 6a6 6 0 1 0 0 12a6 6 0 1 0 0-12M12 10a2 2 0 1 0 0 4a2 2 0 1 0 0-4',
    calendar:'M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2',
    layers:'m12 3 10 6-10 6L2 9zM2 13l10 6 10-6M2 17l10 6 10-6',
    clock:'M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20M12 6v6l4 2',
    shield:'m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6zM8 12l3 3 5-6',
    message:'M21 11a9 9 0 0 1-9 9H4l-3 3V11a10 10 0 0 1 20 0M7 9h10M7 13h6',
    refresh:'M20 8a8 8 0 0 0-14-4L3 7M3 2v5h5M4 16a8 8 0 0 0 14 4l3-3M16 17h5v5',
    chart:'M4 3v18h17M8 16v-5M13 16V7M18 16v-8',
    check:'M4 12l5 5L20 5',
    phone:'M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2M11 18h2',
    cloud:'M6 18a5 5 0 1 1 1-10a7 7 0 0 1 13 3a4 4 0 0 1-1 7z',
    spark:'m12 2 3 7 7 3-7 3-3 7-3-7-7-3 7-3z',
    bell:'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4',
    play:'m9 4 12 8-12 8z',
    speaker:'M3 9h4l5-4v14l-5-4H3zM16 8a6 6 0 0 1 0 8M19 5a10 10 0 0 1 0 14',
    expand:'M8 3H3v5M16 3h5v5M21 16v5h-5M8 21H3v-5',
    left:'m15 5-7 7 7 7',right:'m9 5 7 7-7 7',
    download:'M12 3v12M7 10l5 5 5-5M4 15v6h16v-6',
    database:'M20 5c0 2-4 3-8 3S4 7 4 5s4-3 8-3 8 1 8 3M4 5v14c0 2 4 3 8 3s8-1 8-3V5M4 12c0 2 4 3 8 3s8-1 8-3'
  };
  const icon = name => `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><path d="${paths[name] || paths.book}"/></svg>`;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const isPresenter = new URLSearchParams(location.search).has('presenter');
  const channel = typeof BroadcastChannel !== 'undefined' ? new BroadcastChannel('mochii-project-presentation') : null;
  let slides = [], current = 0, release = null;
  let clock = {accumulated:0, startedAt:null};
  let noticeTimer;
  function notice(text) {
    let node = document.getElementById('notice');
    if (!node) { node = document.createElement('div'); node.id='notice'; node.className='notice'; node.setAttribute('role','status'); document.body.append(node); }
    node.textContent = text; node.hidden = false;
    clearTimeout(noticeTimer); noticeTimer = setTimeout(() => node.hidden = true, 5000);
  }
  function decorate(root = document) {
    root.querySelectorAll('[data-icon]').forEach(el => el.insertAdjacentHTML('afterbegin',icon(el.dataset.icon)));
  }
  function art(animated = true) {
    return `<div class="hero-art"><picture><source media="(prefers-reduced-motion: reduce)" srcset="assets/brand/mochii-poster.png"><img src="assets/brand/${animated?'mochii-reading.webp':'mochii-poster.png'}" alt="Mochii đọc sách, chớp mắt và lật trang" loading="lazy" width="420" height="460"></picture></div>`;
  }
  function heading(s, level=2, center=false) {
    return `<div class="heading${center?' center':''}"><p class="kicker">${esc(s.kicker)}</p><h${level} tabindex="-1">${esc(s.title)}<span class="accent">${esc(s.accent)}</span></h${level}><p class="lead">${esc(s.lead)}</p></div>`;
  }
  function cards(items) { return `<div class="cards">${items.map(([i,h,p])=>`<article class="card"><span class="icon-wrap">${icon(i)}</span><h3>${esc(h)}</h3><p>${esc(p)}</p></article>`).join('')}</div>`; }
  function bullets(items) {return `<div class="bullets">${items.map(([i,h,p])=>`<div class="bullet"><span class="bullet-icon">${paths[i]?icon(i):esc(i)}</span><div><h3>${esc(h)}</h3><p>${esc(p)}</p></div></div>`).join('')}</div>`;}
  function slideBody(s) {
    switch (s.kind) {
      case 'hero': return `${heading(s,1)}<div class="tags">${s.tags.map(t=>`<span class="tag">${esc(t)}</span>`).join('')}</div>`;
      case 'problem': return heading(s,2,true)+cards(s.cards);
      case 'flow': return heading(s,2,true)+`<div class="workflow">${s.steps.map(([i,h,p],n)=>`<article class="step"><div class="step-no">${String(n+1).padStart(2,'0')}${icon(i)}</div><h3>${esc(h)}</h3><p>${esc(p)}</p></article>`).join('')}</div><p class="flow-caption">Mục tiêu → Kế hoạch → Phiên học → Ôn tập → Điều chỉnh</p>`;
      case 'timeline': return `<div>${heading(s)}<p class="takeaway">${esc(s.takeaway)}</p></div><div class="timeline">${s.timeline.map(([t,h,p])=>`<article class="timeline-item"><span class="timeline-time">${esc(t)}</span><div><h3>${esc(h)}</h3><p>${esc(p)}</p></div></article>`).join('')}</div>`;
      case 'screenshot': return `<div>${heading(s)}${bullets(s.bullets)}<a class="demo-link" href="${WEB}" target="_blank" rel="noopener">${icon('play')}Mở demo ứng dụng</a></div><figure class="phone"><img src="${esc(s.image)}" alt="${esc(s.imageAlt)}" loading="lazy" width="632" height="1278"></figure>`;
      case 'reminders': return `<div>${heading(s)}${bullets(s.bullets)}</div><div class="proof-panel"><img src="assets/notification-verified.webp" alt="Thông báo kết thúc phiên tập trung của Mochii xuất hiện trên Android" loading="lazy"><p class="proof-caption">${esc(s.footnote)}</p><div class="split-roles"><div class="role">${icon('spark')}<div><strong>AI chuẩn bị câu chữ</strong><span>Soạn khi có mạng, lưu sẵn trên máy.</span></div></div><div class="role">${icon('bell')}<div><strong>Quy tắc + Android thực thi</strong><span>Ngày giờ, hoạt động, quyền và hạn mức.</span></div></div></div></div>`;
      case 'learning': return heading(s,2,true)+cards(s.cards)+`<p class="learning-quote">Hiểu một định lý còn là biết khi nào không nên áp dụng nó.</p><p class="footnote">${esc(s.footnote)}</p>`;
      case 'experience': return `<div>${heading(s)}${bullets(s.cards)}</div>${art(false)}`;
      case 'architecture': return heading(s,2,true)+`<div class="architecture"><section class="arch-zone"><h3 class="zone-label">Trên thiết bị</h3><div class="arch-row">${icon('phone')}<div><strong>Flutter</strong><span>Giao diện và luồng học tập.</span></div></div><div class="arch-row">${icon('database')}<div><strong>SharedPreferences</strong><span>Trạng thái học tập, cấu hình, nội dung nhắc đã lưu.</span></div></div><div class="arch-row">${icon('bell')}<div><strong>Thông báo Android</strong><span>Hẹn nhắc và báo hết giờ theo quyền hệ điều hành.</span></div></div></section><div class="arch-bridge">${icon('right')}Kết nối<br>khi cần</div><section class="arch-zone"><h3 class="zone-label">Dịch vụ mạng</h3><div class="arch-row">${icon('spark')}<div><strong>Nhà cung cấp AI</strong><span>Gợi ý kế hoạch, giải thích, sinh nội dung ôn tập.</span></div></div><div class="arch-row">${icon('cloud')}<div><strong>Supabase</strong><span>Tài khoản và dữ liệu học tập theo tài khoản.</span></div></div><div class="arch-row">${icon('bell')}<div><strong>Firebase Cloud Messaging</strong><span>Kênh nhận thông báo đẩy từ xa.</span></div></div></section></div><p class="footnote">Đồng hồ và lời nhắc đã lưu không cần gọi AI lúc phát. Hỏi AI và đồng bộ cần mạng; dịch vụ miễn phí có hạn mức.</p>`;
      case 'evidence': return heading(s,2,true)+`<div class="evidence-grid">${s.columns.map(([h,items])=>`<section class="evidence-column"><h3>${esc(h)}</h3><ul>${items.map(t=>`<li>${esc(t)}</li>`).join('')}</ul></section>`).join('')}</div>`;
      case 'roadmap': return heading(s,2,true)+cards(s.cards)+`<p class="footnote">${esc(s.footnote)}</p>`;
      case 'download': return `<div>${heading(s)}<p class="takeaway">Cảm ơn thầy cô và hội đồng.<br>Xin mời trải nghiệm và góp ý.</p><p class="install-note">APK đa kiến trúc, từ Android 7.0.<br>Cho phép cài từ nguồn tải xuống và bật quyền thông báo khi muốn thử nhắc học.</p></div><div class="qr-pair"><article class="qr-card"><img src="assets/qr-web.png" width="190" height="190" alt="QR mở bản Web của Mochii" loading="lazy"><h3>Trải nghiệm Web</h3><p>Mở nhanh trên trình duyệt.<br>Không cần cài đặt.</p><a href="${WEB}" target="_blank" rel="noopener">${icon('play')}Mở Web</a></article><article class="qr-card"><img src="assets/qr-apk.png" width="190" height="190" alt="QR tải bản APK mới nhất của Mochii" loading="lazy"><h3>Tải APK Android</h3><p data-release-caption>Đang kiểm tra phiên bản…</p><a href="${APK}" data-download-link>${icon('download')}Tải APK</a></article></div>`;
    }
  }
  const payload = () => ({type:'state',current,clock});
  function publish() { channel?.postMessage(payload()); }
  function updateMain(index, announce = false) {
    current = Math.max(0,Math.min(slides.length-1,index));
    document.querySelectorAll('.slide').forEach((el,i)=>el.hidden=i!==current);
    document.querySelectorAll('.indicator').forEach((el,i)=>{
      el.setAttribute('aria-current',String(i===current)); el.tabIndex=i===current?0:-1;
    });
    document.getElementById('counter').textContent=`${String(current+1).padStart(2,'0')} / ${slides.length}`;
    document.getElementById('previous').disabled=current===0;
    document.getElementById('next').disabled=current===slides.length-1;
    history.replaceState(null,'',`#slide-${current+1}`);
    document.getElementById('deck').scrollTop=0;
    if(announce) document.querySelector(`#slide-${current+1} h1, #slide-${current+1} h2`)?.focus({preventScroll:true});
    publish();
  }
  function elapsed() {return clock.accumulated+(clock.startedAt===null?0:Date.now()-clock.startedAt);}
  function toggleClock() {
    if(clock.startedAt===null) clock.startedAt=Date.now();
    else {clock.accumulated+=Date.now()-clock.startedAt;clock.startedAt=null;}
    publish();
  }
  function sendAction(action,value) {
    if(isPresenter) channel?.postMessage({type:'action',action,value});
    else if(action==='goto') updateMain(value,true);
    else if(action==='timer') toggleClock();
    else if(action==='resetTimer') {clock={accumulated:0,startedAt:null};publish();}
  }
  function updatePresenter() {
    const s=slides[current];
    document.getElementById('speaker-current').innerHTML=`<p class="speaker-label">Trang ${current+1} / ${slides.length} · khoảng ${s.seconds} giây</p><h2>${esc(s.title)} ${esc(s.accent)}</h2><ul>${s.notes.map(n=>`<li>${esc(n)}</li>`).join('')}</ul><p class="speaker-transition"><strong>Chuyển ý:</strong> ${esc(s.transition)}</p>`;
    const next=slides[current+1];
    document.getElementById('speaker-next').textContent=next?`${current+2}. ${next.title} ${next.accent}`:'Kết thúc phần trình bày. Mời hội đồng hỏi đáp.';
    document.getElementById('speaker-previous').disabled=current===0;
    document.getElementById('speaker-forward').disabled=current===slides.length-1;
  }
  async function updateRelease() {
    try {
      const res=await fetch('release.json',{cache:'no-store'}); if(!res.ok)throw Error('release');
      release=await res.json();
      if(!/^\d+\.\d+\.\d+$/.test(release.version)||!Number.isInteger(release.build))throw Error('metadata');
      document.querySelectorAll('[data-release-caption]').forEach(el=>el.textContent=`v${release.version} · build ${release.build}\n${(release.sizeBytes/1000000).toFixed(1)} MB · Android ARM64`);
      document.querySelectorAll('[data-download-link]').forEach(el=>el.href=`${APK}?build=${release.build}`);
    } catch(_) {
      document.querySelectorAll('[data-release-caption]').forEach(el=>el.textContent='Bản Android hiện hành.\nMở link để kiểm tra tải xuống.');
    }
  }
  try {
    const res=await fetch('deck-data.json',{cache:'no-store'}); if(!res.ok)throw Error('slides');
    slides=await res.json();
    if(!Array.isArray(slides)||slides.length!==12)throw Error('slides');
  } catch(_) {
    document.getElementById('deck').innerHTML='<p class="initial-status" role="alert">Chưa mở được bộ slide. Kiểm tra mạng và tải lại trang.</p>';
    return;
  }
  if(isPresenter) {
    document.title='Mochii — Cửa sổ người thuyết trình';
    document.body.className='speaker-body';
    document.body.innerHTML=`<header class="speaker-header"><div><h1>Mochii · Người thuyết trình</h1><p>Đặt cửa sổ này trên màn hình cá nhân, không chiếu cho khán giả.</p></div><span id="speaker-time" class="speaker-time">00:00</span></header><div class="speaker-controls"><button class="tool-btn" id="speaker-previous">${icon('left')}Trang trước</button><button class="tool-btn" id="speaker-forward">Trang tiếp${icon('right')}</button><button class="tool-btn" id="speaker-timer">Bắt đầu tính giờ</button><button class="tool-btn" id="speaker-reset">Đặt lại giờ</button></div><div class="speaker-grid"><section id="speaker-current"></section><section><p class="speaker-label">Trang tiếp theo</p><p id="speaker-next" class="speaker-next"></p><hr style="border:0;border-top:1px solid var(--line);margin:25px 0"><p class="speaker-estimate">Bài trình bày gợi ý: 12 phút 30 giây.<br>Hỏi đáp tính riêng.<br><br>Phím ← → chuyển trang; T bắt đầu/tạm dừng giờ.<br><br>Nếu mất mạng lúc demo, dùng ảnh chụp và nói rõ đó là ảnh minh họa.</p><a class="tool-btn" href="kich-ban-thuyet-trinh.md" download>Toàn bộ kịch bản</a></section></div>`;
    document.getElementById('speaker-previous').onclick=()=>sendAction('goto',current-1);
    document.getElementById('speaker-forward').onclick=()=>sendAction('goto',current+1);
    document.getElementById('speaker-timer').onclick=()=>sendAction('timer');
    document.getElementById('speaker-reset').onclick=()=>sendAction('resetTimer');
    updatePresenter();
    setInterval(()=>{
      const seconds=Math.floor(elapsed()/1000);
      document.getElementById('speaker-time').textContent=`${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`;
      document.getElementById('speaker-timer').textContent=clock.startedAt===null?'Bắt đầu / tiếp tục':'Tạm dừng';
    },500);
    channel?.postMessage({type:'requestState'});
  } else {
    document.getElementById('deck').innerHTML=slides.map((s,i)=>{
      const two=['hero','timeline','screenshot','reminders','experience','download'].includes(s.kind);
      let content=slideBody(s);
      if(s.kind==='hero')content=`<div>${content}</div>${art()}`;
      return `<section class="slide ${two?'two-column':''} kind-${esc(s.kind)}" id="slide-${i+1}" aria-label="Trang ${i+1}" ${i?'hidden':''}>${content}</section>`;
    }).join('');
    document.getElementById('indicators').innerHTML=slides.map((s,i)=>`<button class="indicator" data-slide="${i}" aria-label="Trang ${i+1}: ${esc(s.title)}" aria-current="${i===0}"></button>`).join('');
    document.querySelectorAll('[data-slide]').forEach(el=>el.onclick=()=>updateMain(Number(el.dataset.slide),true));
    document.getElementById('previous').onclick=()=>updateMain(current-1,true);
    document.getElementById('next').onclick=()=>updateMain(current+1,true);
    document.getElementById('fullscreen-button').onclick=async()=>{
      try {if(document.fullscreenElement)await document.exitFullscreen();else await document.documentElement.requestFullscreen();}
      catch(_){notice('Trình duyệt chưa cho phép toàn màn hình. Bạn có thể dùng phím F11.');}
    };
    document.getElementById('presenter-button').onclick=()=>{
      const url=new URL('index.html',location.href);url.search='presenter=1';url.hash='';
      const popup=window.open(url.href,'mochii-presenter','width=1100,height=800');
      if(!popup)notice('Cho phép cửa sổ bật lên để mở lời dẫn trên màn hình riêng.');
    };
    decorate();
    const fromHash=Number(location.hash.match(/slide-(\d+)/)?.[1]||1)-1;
    updateMain(fromHash);
    window.addEventListener('hashchange',()=>updateMain(Number(location.hash.match(/slide-(\d+)/)?.[1]||1)-1));
    let touch;
    document.getElementById('deck').addEventListener('touchstart',e=>{touch={x:e.changedTouches[0].screenX,y:e.changedTouches[0].screenY};},{passive:true});
    document.getElementById('deck').addEventListener('touchend',e=>{
      if(!touch)return;
      const dx=e.changedTouches[0].screenX-touch.x,dy=e.changedTouches[0].screenY-touch.y;
      if(Math.abs(dx)>75&&Math.abs(dx)>Math.abs(dy)*1.5)updateMain(current+(dx<0?1:-1),true);
      touch=null;
    },{passive:true});
    updateRelease();
  }
  channel?.addEventListener('message',e=>{
    const m=e.data;
    if(!m||typeof m!=='object')return;
    if(m.type==='requestState'&&!isPresenter)publish();
    else if(m.type==='state'&&isPresenter){current=m.current;clock=m.clock;updatePresenter();}
    else if(m.type==='action'&&!isPresenter){
      if(m.action==='goto'&&Number.isInteger(m.value))sendAction('goto',m.value);
      else if(m.action==='timer'||m.action==='resetTimer')sendAction(m.action);
    }
  });
  document.addEventListener('keydown',e=>{
    if(e.altKey||e.ctrlKey||e.metaKey||e.target.closest('input,textarea,select,[contenteditable]'))return;
    if(e.key===' '&&e.target.closest('button,a'))return;
    if(['ArrowRight','PageDown',' '].includes(e.key)){e.preventDefault();sendAction('goto',current+1);}
    else if(['ArrowLeft','PageUp'].includes(e.key)){e.preventDefault();sendAction('goto',current-1);}
    else if(e.key==='Home'){e.preventDefault();sendAction('goto',0);}
    else if(e.key==='End'){e.preventDefault();sendAction('goto',slides.length-1);}
    else if(e.key.toLowerCase()==='p'&&!isPresenter)document.getElementById('presenter-button').click();
    else if(e.key.toLowerCase()==='f'&&!isPresenter)document.getElementById('fullscreen-button').click();
    else if(e.key.toLowerCase()==='t')sendAction('timer');
  });
  window.MochiiDeck={goTo:index=>sendAction('goto',index),get current(){return current;},get count(){return slides.length;},get release(){return release;}};
})();
