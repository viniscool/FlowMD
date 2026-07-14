document.querySelectorAll('[data-nav]').forEach(a=>a.addEventListener('click',()=>localStorage.setItem('flowmd-last-page',a.href)));
