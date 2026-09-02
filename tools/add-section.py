#!/usr/bin/env python3
"""add-section.py <page.md> <before-heading> <s-summary-a,s-summary-b,...> < section.md

Ripple helper: inserts the Markdown read from stdin before the line that equals
<before-heading> (e.g. '## Related'; falls back to '## Sources', then end of
file), adds every listed summary slug to the page's frontmatter `sources:` list
and to the last line of its '## Sources' section (as [[links]]), and sets
`updated:` to today's date (override with the WIKI_DATE environment variable).

Call it directly in zsh — NOT through a variable like A="python3 tools/add-section.py";
zsh does not word-split that and the call fails silently. A shell function is fine:
  A(){ python3 tools/add-section.py "$@"; }
  A wiki/entities/foo.md "## Related" "s-source-one,s-source-two" <<'EOF'
  ## New section
  - claim (source: [[s-source-one]])
  EOF
"""
import sys,re,io
import datetime, os
TODAY=os.environ.get('WIKI_DATE') or datetime.date.today().isoformat()   # override with WIKI_DATE=YYYY-MM-DD
path,before,srcs=sys.argv[1],sys.argv[2],[s for s in sys.argv[3].split(',') if s]
text=sys.stdin.read().rstrip('\n')+'\n\n'
doc=open(path,encoding='utf-8').read()
# frontmatter sources
m=re.search(r'^sources:[ \t]*\[(.*?)\][ \t]*(?:#.*)?$',doc,flags=re.M|re.S)   # the list may wrap over several lines; it is rewritten on one
if m:
    cur=[s.strip() for s in m.group(1).split(',') if s.strip()]
    for s in srcs:
        if s not in cur: cur.append(s)
    doc=doc[:m.start()]+'sources: ['+', '.join(cur)+']'+doc[m.end():]
doc=re.sub(r'^updated:.*$','updated: '+TODAY,doc,count=1,flags=re.M)
lines=doc.split('\n')
idx=None
for i,l in enumerate(lines):
    if l.strip()==before: idx=i; break
if idx is None:
    for i,l in enumerate(lines):
        if l.strip()=='## Sources': idx=i; break
if idx is None:
    lines.append(''); idx=len(lines)
lines[idx:idx]=text.split('\n')
doc='\n'.join(lines)
# Sources line: last non-empty line after '## Sources'
si=doc.rfind('\n## Sources')
if si>=0:
    ni=doc.find('\n## ',si+1)            # the section ends at the next heading, not at the end of the page --
    tail,rest=(doc[si:],'') if ni<0 else (doc[si:ni],doc[ni:])   # a page with '## To verify' after it got the link there
    tl=tail.rstrip('\n').split('\n')
    # find last non-empty line
    for j in range(len(tl)-1,0,-1):
        if tl[j].strip():
            add=[f'[[{s}]]' for s in srcs if f'[[{s}]]' not in tl[j]]
            if add: tl[j]=tl[j].rstrip()+' · '+' · '.join(add)
            break
    doc=doc[:si]+'\n'.join(tl)+'\n'+rest
open(path,'w',encoding='utf-8').write(doc)
print("updated",path)
