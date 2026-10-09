r={54:0.49,108:1.0,215:2.06,429:4.26,857:8.8}
AN=83.6; G=7.0; G4=13.8  # analysis fwd-equiv; gradient run (stand+own invader); with two corners
def pair(a,b): return r[a]+r[b]
out={}
# today as used: pilot, u108 everywhere, report, diagnose once
today=0.3+AN*1+G*1+0.75*G
out['today']=(today,today)
# A
A_ld=AN*1+2*pair(108,215)+G*(r[215]+r[108]+r[54])
A_ep=AN*1+(2*pair(108,215)+G*(r[215]+r[108]+r[54]))+(2*pair(215,429)+G*(r[429]+r[215]+r[108]))+(2*pair(429,857)+G*(r[857]+r[429]+r[215]))
A_ep_staged=A_ep-(G*(r[429]+r[215]+r[108])-r[429])  # 2nd check fails on ln J ratio 0.76: forwards only
A_ep_rule=AN*r[429]+(2*pair(429,857)+G*(r[857]+r[429]+r[215]))
out['A']=(A_ld,A_ep); print('A ep staged',round(A_ep_staged,1),'A ep remembered by own rule',round(A_ep_rule,1),'A claimed remembered',84+26.1+105.9)
# B
B_ld=AN*r[215]+G*(r[54]+r[108]+r[215])+G*r[215]+0.3
B_ep=AN*r[857]+G*(r[54]+r[108]+r[215])+G*r[429]+G*r[857]+G*r[857]+0.3
out['B']=(B_ld,B_ep)
# C
C_ld=0.66+AN*pair(108,215)+G*pair(108,215)+G4*(r[108]+r[215]+r[429])-pair(108,215)
C_ep=0.62+1+AN*pair(215,429)+G*pair(215,429)+G4*(r[215]+r[429]+r[857])-pair(215,429)
out['C']=(C_ld,C_ep)
# D
D_ld=AN*pair(108,215)+G*pair(108,215)+0.63+G*(r[54]+r[108]+r[215])
D_ep=AN*pair(429,857)+G*pair(429,857)+0.63+G*(r[54]+r[108]+r[215])+G*r[429]+G*r[857]
out['D']=(D_ld,D_ep); print('D ld thinned', round(D_ld-0.04*(AN+G)*pair(108,215),1))
# floor: pair 108/215 everywhere, pilot, diagnose rung
fl=0.3+AN*pair(108,215)+G*pair(108,215)+G*r[54]
print('floor ld',round(fl,1))
for k,(l,e) in out.items():
  print(f"{k:6s} ld {l:7.1f}F = {l*0.637:6.1f}M (share0) {l*0.373:6.1f}M (tf24) | ep {e:7.1f}F = {e*0.416:6.1f}M / {e*0.230:6.1f}M")
