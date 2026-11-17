#!/usr/bin/env python3
"""Exercise local counter projections with synthetic logs, network and real-home access denied."""
from pathlib import Path
import subprocess,json,os,tempfile,datetime,uuid,sys

app=Path(sys.argv[1]).resolve()
helper=app/'Contents/Helpers/OVRCASTCollector'
marker='PRIVATE_CONTENT_MUST_STAY_LOCAL'
now=datetime.datetime.now(datetime.timezone.utc)
stamp=now.isoformat().replace('+00:00','Z')
policy='(version 1)(allow default)(deny network*)(deny file-read* file-write* (subpath (param "PRIVATE_HOME")))(allow file-read* (subpath (param "TEST_APP")))'
results={}
with tempfile.TemporaryDirectory(prefix='ovrcast-token-fixture-') as folder:
 home=Path(folder);codex=home/'.codex';claude=home/'.claude'
 sessions=codex/'sessions';sessions.mkdir(parents=True)
 projects=claude/'projects/fixture-project';projects.mkdir(parents=True)
 usage={'input_tokens':100,'cached_input_tokens':40,'output_tokens':20,'reasoning_output_tokens':5,'total_tokens':120}
 events=[{'timestamp':stamp,'type':'session_meta','payload':{'id':str(uuid.uuid4()),'cwd':'/tmp/fixture','source':'cli','model_provider':'openai'}},
         {'timestamp':stamp,'type':'turn_context','payload':{'model':'gpt-5','cwd':'/tmp/fixture'}},
         {'timestamp':stamp,'type':'response_item','payload':{'type':'message','role':'user','content':[{'type':'input_text','text':marker}]}},
         {'timestamp':stamp,'type':'event_msg','payload':{'type':'token_count','info':{'total_token_usage':usage,'last_token_usage':usage}}}]
 (sessions/'rollout-fixture.jsonl').write_text(''.join(json.dumps(x)+'\n' for x in events))
 message={'timestamp':stamp,'type':'assistant','uuid':str(uuid.uuid4()),'requestId':'req-fixture','sessionId':'session-fixture','isSidechain':False,
          'message':{'id':'msg-fixture','type':'message','role':'assistant','model':'claude-sonnet-4-5-20250929','content':[{'type':'text','text':marker}],
          'usage':{'input_tokens':100,'output_tokens':20,'cache_read_input_tokens':50,'cache_creation_input_tokens':10}}}
 # Duplicate delivery of the same request must not multiply its token counters.
 (projects/'session-fixture.jsonl').write_text((json.dumps(message)+'\n')*2)
 env={'PATH':'/usr/bin:/bin:/usr/sbin:/sbin','HOME':str(home),'CFFIXED_USER_HOME':str(home),'CODEX_HOME':str(codex),
      'CLAUDE_CONFIG_DIR':str(claude),'XDG_CACHE_HOME':str(home/'.cache'),'XDG_CONFIG_HOME':str(home/'.config'),'TMPDIR':folder,'TZ':'America/New_York'}
 for provider,expected in [('codex',120),('claude',180),('antigravity',None)]:
  cmd=['/usr/bin/sandbox-exec','-D','PRIVATE_HOME='+str(Path.home()),'-D','TEST_APP='+str(app),'-p',policy,str(helper),'token-activity','--provider',provider]
  r=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=65)
  assert r.returncode==0, (provider,r.returncode,r.stderr[-1000:])
  assert marker not in r.stdout
  d=json.loads(r.stdout)
  assert set(d)<=set(['schemaVersion','provider','generatedAt','timeZone','historyComplete','scanComplete','days','error'])
  assert d['schemaVersion']==1 and d['provider']==provider
  assert d['historyComplete'] is False
  for row in d['days']:
   assert set(row)<=set(['date','input','output','cacheRead','cacheWrite','total'])
   assert all(v is None or isinstance(v,int) and not isinstance(v,bool) and v>=0 for k,v in row.items() if k!='date')
  total=sum(x['total'] for x in d['days'] if x.get('total') is not None)
  if expected is not None:assert total==expected,(provider,total,d)
  results[provider]={'networkDenied':True,'realHomeDenied':True,'numericProjectionOnly':True,'fixtureTotal':total,'rows':len(d['days']),'historyComplete':d['historyComplete'],'scanComplete':d['scanComplete'],'unavailable':d.get('error') is not None}
 cache=home/'Library/Caches/OVRCAST/TokenActivity'
 assert cache.exists() and cache.stat().st_mode & 0o777==0o700
 results['cacheOwnerOnly']=True
 print(json.dumps(results,indent=2))
