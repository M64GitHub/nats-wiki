#!/usr/bin/env python3
"""html-to-text.py <page.html> <out.txt>

Crude, dependency-free HTML → text for saving web sources verbatim under raw/.
Drops <script>/<style>/<head>, turns headings into '# ' lines, list items into
'- ', table cells into ' | ', keeps paragraph breaks, unescapes entities.
Navigation and footers survive at the top/bottom — that is intended (verbatim).

Typical use (zsh; always pass a browser User-Agent, some sites 403 otherwise):
  UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
  curl -sL -A "$UA" -o /tmp/page.html "https://example.org/article"   # add -k for c64.com (bad cert chain)
  python3 tools/html-to-text.py /tmp/page.html raw/<collection>/<slug>.txt
"""
src=open(sys.argv[1],encoding='utf-8',errors='replace').read()
t=re.sub(r'(?is)<(script|style|noscript|svg|head)\b.*?</\1>','',src)
t=re.sub(r'(?is)<!--.*?-->','',t)
t=re.sub(r'(?i)<br\s*/?>','\n',t)
t=re.sub(r'(?i)</(p|div|li|tr|h[1-6]|blockquote|pre|dd|dt|table|section|article|ul|ol)>','\n',t)
t=re.sub(r'(?i)<(h[1-6])[^>]*>',lambda m:'\n'+'#'*int(m.group(1)[1])+' ',t)
t=re.sub(r'(?i)<(li)[^>]*>','\n- ',t)
t=re.sub(r'(?i)<(td|th)[^>]*>',' | ',t)
t=re.sub(r'(?s)<[^>]+>','',t)
t=html.unescape(t)
t=re.sub(r'[ \t\xa0]+',' ',t)
t=re.sub(r' *\n *','\n',t)
t=re.sub(r'\n{3,}','\n\n',t)
open(sys.argv[2],'w',encoding='utf-8').write(t.strip()+'\n')
print(sys.argv[2], len(t.split()), "words")
