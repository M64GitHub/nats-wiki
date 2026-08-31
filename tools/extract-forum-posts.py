#!/usr/bin/env python3
# Extract forum posts (author, timestamp, text) from saved HTML pages for raw/ ingests.
#   python3 tools/extract-forum-posts.py lemon64   page.html [page2.html …] > raw/lemon64/<slug>.txt   (phpBB 3: Lemon64)
#   python3 tools/extract-forum-posts.py chipmusic page.html [page2.html …] > raw/chipmusic/<slug>.txt (PunBB: chipmusic.org)
#   python3 tools/extract-forum-posts.py article   page.html [body|article|main|div] > raw/<coll>/<slug>.txt (generic page → text)
# Fetch pages first with a browser user agent, e.g. curl -sL -A "Mozilla/5.0" -o page.html <url>; chipmusic.org blocks plain fetchers.
# Add the one-line provenance header (title, URL, fetch date, extraction note) to the output yourself. Quotes are prefixed with '> '.
import sys,re,html
from html.parser import HTMLParser
class T(HTMLParser):
    def __init__(s): super().__init__(); s.out=[]; s.q=0; s.skip=0
    def handle_starttag(s,t,a):
        a=dict(a)
        if t in('script','style'): s.skip+=1
        if t=='blockquote': s.q+=1; s.out.append('\n')
        if t in('br','p','div','li','tr','h1','h2','h3','h4','pre'): s.out.append('\n')
        if t=='cite': s.out.append('\n')
    def handle_endtag(s,t):
        if t in('script','style'): s.skip-=1
        if t=='blockquote': s.q-=1; s.out.append('\n')
        if t in('p','div','li','tr','h1','h2','h3','h4','pre','cite'): s.out.append('\n')
    def handle_data(s,d):
        if s.skip: return
        s.out.append(('> ' if s.q else '')+d if s.out and s.out[-1].endswith('\n') else d)
def text(h):
    p=T(); p.feed(h); t=''.join(p.out)
    t=re.sub(r'[ \t]+\n','\n',t); t=re.sub(r'\n{3,}','\n\n',t); t=re.sub(r'^\n(> )?\s*$','',t,flags=re.M)
    return t.strip()
def divblock(s,i):
    # s[i] is at '<div' ; return end index of matching </div>
    d=0; j=i
    for m in re.finditer(r'<div\b|</div>',s[i:]):
        d+= 1 if m.group().startswith('<div') else -1
        if d==0: return i+m.end()
    return len(s)
def lemon64(s):
    posts=[]
    for m in re.finditer(r'<div[^>]*class="post has-profile[^"]*"',s):
        blk=s[m.start():divblock(s,m.start())]
        au=re.search(r'class="username[^"]*">([^<]+)</a>',blk); tm=re.search(r'<time datetime="([^"]+)"',blk)
        c=blk.find('<div class="content">'); body=blk[c:divblock(blk,c)]
        posts.append((au.group(1) if au else '?', tm.group(1) if tm else '?', text(body)))
    return posts
def chipmusic(s):
    posts=[]
    for m in re.finditer(r'<div[^>]*class="post (?:odd|even)[^"]*"',s):
        blk=s[m.start():divblock(s,m.start())]
        num=re.search(r'post-num">(\d+)<',blk); dt=re.search(r'class="permalink"[^>]*>([^<]+)</a>',blk); au=re.search(r'class="username"><a[^>]*>([^<]+)</a>',blk)
        c=blk.find('<div class="post-entry">'); body=blk[c:divblock(blk,c)]
        body=re.sub(r'<div class="postsignature">.*','',body,flags=re.S)
        posts.append((num.group(1) if num else '?', dt.group(1) if dt else '?', au.group(1) if au else '?', text(body)))
    return posts
if __name__=="__main__":
  kind=sys.argv[1]; out=[]
  if kind=='article':
    s=open(sys.argv[2],encoding='utf-8',errors='replace').read(); sel=sys.argv[3] if len(sys.argv)>3 else 'body'
    m=re.search(r'<%s\b[^>]*>'%sel,s,re.I)
    if not m: sys.exit('no <%s> element'%sel)
    if sel=='div': body=s[m.start():divblock(s,m.start())]
    else:
        e=re.search(r'</%s>'%sel,s[m.end():],re.I); body=s[m.end():m.end()+e.start()] if e else s[m.end():]
    body=re.sub(r'<(script|style|nav|header|footer|aside)\b.*?</\1>','',body,flags=re.S|re.I)
    print(html.unescape(text(body))); sys.exit()
  for f in sys.argv[2:]:
    s=open(f,encoding='utf-8',errors='replace').read()
    if kind=='lemon64':
        for au,tm,b in lemon64(s): out.append(f'--- {html.unescape(au)} — {tm}\n{html.unescape(b)}\n')
    else:
        for n,dt,au,b in chipmusic(s): out.append(f'----- post {n} · {dt} · {html.unescape(au)} -----\n{html.unescape(b)}\n')
  print(f'{len(out)} posts',file=sys.stderr); print('\n'.join(out))
