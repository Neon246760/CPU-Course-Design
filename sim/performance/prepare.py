"""Snapshot the user's legacy RTL and create shared, independently checked workloads."""
from pathlib import Path
import argparse, hashlib, json, re, shutil
from datetime import datetime

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'sim/performance'
OUT = ROOT / 'docs/performance'
MASK = 0xffffffff
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def signed(v): return v if v < 0x80000000 else v-0x100000000
def sext(v,n): return v-(1<<n) if v & (1<<(n-1)) else v
def write_mem(p, values): p.write_text(''.join(f'{x&MASK:08x}\n' for x in values),encoding='ascii')

class Program:
    def __init__(self): self.ops=[]; self.labels={}
    def label(self,s): self.labels[s]=len(self.ops)*4
    def emit(self,op,*args): self.ops.append((op,args))
    def build(self):
        words=[]; lines=[]
        for i,(op,a) in enumerate(self.ops):
            for k,v in self.labels.items():
                if v==i*4: lines.append(k+':')
            if op in ('addi','ori','lw'):
                rd,rs,imm=a; f={'addi':0,'ori':6,'lw':2}[op]
                w=((imm&4095)<<20)|(rs<<15)|(f<<12)|(rd<<7)|(3 if op=='lw' else 0x13)
                line=f'{op} x{rd}, {imm}(x{rs})' if op=='lw' else f'{op} x{rd}, x{rs}, {imm}'
            elif op=='sw':
                rs,base,imm=a; n=imm&4095;w=((n>>5)<<25)|(rs<<20)|(base<<15)|(2<<12)|((n&31)<<7)|0x23
                line=f'sw x{rs}, {imm}(x{base})'
            elif op=='beq':
                r1,r2,target=a; n=(self.labels[target]-i*4)&8191
                w=((n>>12)<<31)|(((n>>5)&63)<<25)|(r2<<20)|(r1<<15)|(((n>>1)&15)<<8)|(((n>>11)&1)<<7)|0x63
                line=f'beq x{r1}, x{r2}, {target}'
            else:
                rd,r1,r2=a;f={'add':0,'sub':0,'or':6,'slt':2}[op]
                w=((0x20 if op=='sub' else 0)<<25)|(r2<<20)|(r1<<15)|(f<<12)|(rd<<7)|0x33
                line=f'{op} x{rd}, x{r1}, x{r2}'
            words.append(w);lines.append('    '+line)
        return words,'\n'.join(lines)+'\n'
    def done(self): self.label('done');self.emit('beq',0,0,'done');return self

def reference(words, data, stop):
    regs=[0]*32;mem=(data+[0]*256)[:256];pc=0;trace=[];stores=[];branches=0
    for _ in range(100000):
        assert pc%4==0 and 0<=pc//4<len(words)
        w=words[pc//4];op=w&127;rd=(w>>7)&31;f=(w>>12)&7;r1=(w>>15)&31;r2=(w>>20)&31
        a,b=regs[r1],regs[r2];nxt=pc+4;wr=0;val=0
        if op==0x33:
            assert f in (0,2,6)
            val=(a-b if w>>25==32 else a+b) if f==0 else (a|b if f==6 else int(signed(a)<signed(b)));wr=rd
        elif op==0x13:
            imm=sext(w>>20,12); assert f in (0,6)
            val=a+imm if f==0 else a|(imm&MASK);wr=rd
        elif op==3:
            addr=(a+sext(w>>20,12))&MASK;assert f==2 and addr%4==0 and addr<1024
            val=mem[addr//4];wr=rd
        elif op==0x23:
            addr=(a+sext(((w>>25)<<5)|((w>>7)&31),12))&MASK;assert f==2 and addr%4==0 and addr<1024
            mem[addr//4]=b;stores.append([addr,b])
        elif op==0x63:
            assert f==0;branches+=1
            imm=sext(((w>>31)<<12)|(((w>>7)&1)<<11)|(((w>>25)&63)<<5)|(((w>>8)&15)<<1),13)
            if a==b:nxt=pc+imm
        else: raise ValueError(hex(w))
        if wr:regs[wr]=val&MASK
        trace.append([pc,w,wr,val&MASK if wr else 0])
        if pc==stop:return dict(regs=regs,mem=mem,trace=trace,stores=stores,branches=branches)
        pc=nxt
    raise RuntimeError('reference timeout')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--legacy',type=Path,default=Path(r'D:\Neon\BIT\Grade3\大三下\计算机组成原理\project\lab2'));ap.add_argument('--use-snapshot',action='store_true');args=ap.parse_args()
    (HERE/'legacy').mkdir(parents=True,exist_ok=True);(HERE/'programs').mkdir(exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    manifest={'legacy_root':str(args.legacy),'transformation':'Only whole-token module/type names receive perf_legacy_ prefix; no logic changes.','files':[]}
    names=['cpu_top','alu','control','regfile','imm_gen','imem','dmem']
    for src in ([] if args.use_snapshot else sorted((args.legacy/'lab2.srcs/sources_1/new').iterdir())):
        if src.suffix not in ('.v','.vh'):continue
        dst=HERE/'legacy'/src.name
        content=src.read_text(encoding='utf-8-sig')
        content=re.sub(r'\b('+ '|'.join(names)+r')\b',lambda m:'perf_legacy_'+m[0],content)
        dst.write_text(content,encoding='utf-8')
        manifest['files'].append({'original':str(src),'original_sha256':sha(src),'snapshot':str(dst.relative_to(ROOT)),'snapshot_sha256':sha(dst)})
    workloads={}
    for name,dependent in [('alu_independent',False),('raw_chain',True)]:
        q=Program()
        # Legacy regfile has no reset gate: keep instruction zero inert during reset.
        q.emit('addi',0,0,0)
        for i in range(192):q.emit('addi',1 if dependent else i%6+1,1 if dependent else i%6+1,1)
        q.done();words,asm=q.build();workloads[name]=(words,asm,[],q.labels['done'])
    q=Program();q.emit('addi',1,0,0);q.emit('addi',2,0,128);q.label('loop');q.emit('addi',1,1,1);q.emit('beq',1,2,'done');q.emit('beq',0,0,'loop');q.done()
    w,a=q.build();workloads['branch_loop']=(w,a,[],q.labels['done'])
    q=Program();q.emit('addi',1,0,0);q.emit('addi',2,0,2000);q.label('loop');q.emit('addi',1,1,1);q.emit('beq',1,2,'done');q.emit('beq',0,0,'loop');q.done()
    w,a=q.build();workloads['branch_steady']=(w,a,[],q.labels['done'])
    q=Program();q.emit('addi',1,0,0);q.emit('addi',4,0,4);q.label('pass');q.emit('addi',2,0,0);q.emit('addi',3,0,32);q.label('loop');q.emit('lw',5,2,0);q.emit('add',1,1,5);q.emit('addi',2,2,4);q.emit('addi',3,3,-1);q.emit('beq',3,0,'end_pass');q.emit('beq',0,0,'loop');q.label('end_pass');q.emit('addi',4,4,-1);q.emit('beq',4,0,'done');q.emit('beq',0,0,'pass');q.done()
    w,a=q.build();workloads['load_use_sum']=(w,a,list(range(1,33)),q.labels['done'])
    q=Program();q.emit('addi',1,0,0);q.emit('addi',2,0,256);q.emit('addi',3,0,32);q.label('loop');q.emit('lw',4,1,0);q.emit('sw',4,2,0);q.emit('addi',1,1,4);q.emit('addi',2,2,4);q.emit('addi',3,3,-1);q.emit('beq',3,0,'done');q.emit('beq',0,0,'loop');q.done()
    w,a=q.build();workloads['memory_copy']=(w,a,list(range(1,33)),q.labels['done'])
    orig=args.legacy/'lab2.srcs/sim_1/new'
    words=[int(x,16) for x in (OUT/'historical_imem_sort.mem' if args.use_snapshot else orig/'imem_sort.mem').read_text().split()]
    data=[int(x,16) for x in (OUT/'historical_dmem_init.mem' if args.use_snapshot else orig/'dmem_init.mem').read_text().split()]
    asm=(OUT/'historical_sort.S').read_text(encoding='utf-8') if args.use_snapshot else (args.legacy/'riscv1.asm').read_bytes().decode('gb18030',errors='replace')
    workloads['legacy_sort5']=(words,asm,data,80)
    for filename in (() if args.use_snapshot else ('imem_sort.mem','dmem_init.mem')):
        shutil.copy2(orig/filename,OUT/('historical_'+filename))
    hist=args.legacy/'lab2.runs/impl_1/cpu_top_timing_summary_routed.rpt'
    if not args.use_snapshot:
        shutil.copy2(hist,OUT/'historical_timing_summary.rpt')
        (OUT/'historical_sort.S').write_text(asm,encoding='utf-8')
    for src in ([] if args.use_snapshot else [orig/'imem_sort.mem',orig/'dmem_init.mem',args.legacy/'riscv1.asm',hist]):
        manifest['files'].append({'original':str(src),'original_sha256':sha(src)})
    results={}
    for name,(words,asm,data,stop) in workloads.items():
        assert len(words)<=256
        ref=reference(words,data,stop);d=HERE/'programs'/name;d.mkdir(exist_ok=True)
        write_mem(d/'imem.mem',words+[0x13]*(256-len(words)));write_mem(d/'dmem.mem',(data+[0]*256)[:256]);(d/'program.S').write_text(asm,encoding='utf-8')
        for j,key in enumerate(['pc','instr','rd','value']):write_mem(d/(key+'.mem'),[r[j] for r in ref['trace']])
        write_mem(d/'regs.mem',ref['regs']);write_mem(d/'final_dmem.mem',ref['mem'])
        write_mem(d/'store_addr.mem',[r[0] for r in ref['stores']] or [0]);write_mem(d/'store_value.mem',[r[1] for r in ref['stores']] or [0])
        results[name]={'instructions':len(ref['trace']),'static_words':len(words),'stop_pc':stop,'stores':len(ref['stores']),'branches':ref['branches'],'imem_sha256':sha(d/'imem.mem'),'data_sha256':sha(d/'dmem.mem'),'registers':ref['regs'],'memory':ref['mem']}
    assert results['legacy_sort5']['memory'][:5]==[1,3,5,7,9]
    assert results['load_use_sum']['registers'][1]==2112
    assert results['memory_copy']['memory'][64:96]==list(range(1,33))
    assert results['raw_chain']['registers'][1]==192
    assert results['alu_independent']['registers'][1:7]==[32]*6
    assert results['branch_loop']['registers'][1]==128
    if not args.use_snapshot:
        (OUT/'source_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    else:
        manifest=json.loads((OUT/'source_manifest.json').read_text(encoding='utf-8'))
        for entry in manifest['files']:
            if 'snapshot' in entry:assert sha(ROOT/entry['snapshot'])==entry['snapshot_sha256'],entry['snapshot']
    current={'prepared_at':datetime.now().astimezone().isoformat(),'rtl':[{'path':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in sorted((ROOT/'rtl').rglob('*.sv'))]}
    (OUT/'current_sources.json').write_text(json.dumps(current,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'workloads.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    (HERE/'perf_paths.vh').write_text('`define PERF_ROOT "'+ROOT.as_posix()+'"\n',encoding='utf-8')
    total=len(results)*6
    lines=['`timescale 1ns/1ps','module tb_performance;',f'  wire [{total-1}:0] done;']
    n=0
    for name,m in results.items():
        for cfg in range(6):
            lines.append(f'  perf_case #(.NAME("{name}"), .CONFIG({cfg}), .N({m["instructions"]}), .STORES({m["stores"]})) c{n}(.done(done[{n}]));');n+=1
    lines+=[f'  initial begin wait (&done); #10; $display("PERFORMANCE_ALL_PASS {total}"); $finish; end','  initial begin #2000000; $fatal(1,"global timeout"); end','endmodule']
    (HERE/'tb_performance.sv').write_text('\n'.join(lines)+'\n',encoding='ascii')
    print(json.dumps({n:{k:v for k,v in r.items() if k in ('instructions','stores','branches')} for n,r in results.items()},indent=2))
if __name__=='__main__':main()
