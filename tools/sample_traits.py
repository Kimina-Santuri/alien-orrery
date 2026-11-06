import http.server,threading,json,sys
ROOT='/Users/mac/Documents/alien-orrery'; PORT=8464; res={}; done=threading.Event()
PAGE="""<!doctype html><body><script>
const N=%d;
const mk=(w,h)=>new Promise(ok=>{const f=document.createElement('iframe');f.style.cssText=`position:fixed;left:0;top:0;border:0;width:${w}px;height:${h}px`;f.src='index.html?explore=1&still=1&seed=7';f.onload=()=>setTimeout(()=>ok(f),500);document.body.append(f)});
(async()=>{const f=await mk(240,180);const w=f.contentWindow;const out=[];
 const cmp=[];
 for(let i=1;i<=N;i++){out.push(w.orrery.traitsFor(i));if(i%%5===0)await new Promise(r=>setTimeout(r,0));}
 for(const [a,b] of [[1440,900],[390,844]]){f.style.width=a+'px';f.style.height=b+'px';await new Promise(r=>setTimeout(r,300));const x=[];for(let i=1;i<=40;i++)x.push(w.orrery.traitsFor(i));cmp.push({size:[a,b],x});}
 await fetch('/report',{method:'POST',body:JSON.stringify({out,cmp})});})();
</script>"""
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s,*a,**k): super().__init__(*a,directory=ROOT,**k)
    def log_message(s,*a): pass
    def do_GET(s):
        if s.path.startswith('/sampler'):
            b=(PAGE%int(sys.argv[1])).encode(); s.send_response(200);s.send_header('Content-Type','text/html');s.send_header('Content-Length',str(len(b)));s.end_headers();s.wfile.write(b)
        else: super().do_GET()
    def do_POST(s):
        d=s.rfile.read(int(s.headers['Content-Length']));open(sys.argv[2],'wb').write(d);s.send_response(200);s.send_header('Content-Length','0');s.end_headers();done.set()
srv=http.server.ThreadingHTTPServer(('127.0.0.1',PORT),H);threading.Thread(target=srv.serve_forever,daemon=True).start();done.wait(float(sys.argv[3]));print('done',done.is_set())
