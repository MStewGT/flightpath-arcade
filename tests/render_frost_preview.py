"""Optional Pillow/lupa illustration of actual Lua region crops, not a WoW capture."""
from pathlib import Path
import os
from PIL import Image,ImageDraw,ImageFont
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
os.chdir(root)
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((root/'tests/run.lua').read_text())
lua.execute('''
function frostPreview(air)
 local a=FlightpathArcade;a:Open();a:Start('frost');local g=a.game
 g.distance=48;g.time=8;g.inv=0;g.paused=false;a.paused=false;g.bonus=35
 local entries={{'treeTall',70,16},{'deadTree',400,25},{'treeTall',310,545},{'tree',4,300},{'rock',200,250},{'ramp',280,455},{'stump',85,475},{'snowman',345,480},{'treeTall',90,270}}
 for i,e in ipairs(entries) do local o=g.objects[i];o.active=true;o.kind=e[1];o.x=e[2];o.y=e[3] end
 local gate=g.gates[1];gate.active=true;gate.x=245;gate.y=350;gate.resolved=false
 if air then g.jump=.55;g.jumpDuration=1.1;g.monster='lunge';g.gap=38;g.lane=240;g.mt=.6 end
 a:Render()
 local textures={}
 for _,group in ipairs({a.frostTerrain,a.frostDecor,a.frostPool}) do for _,t in ipairs(group) do textures[#textures+1]=t end end
 for _,pair in ipairs(a.frostGates) do for _,t in ipairs(pair) do textures[#textures+1]=t end end
 textures[#textures+1]=a.frostBeast;textures[#textures+1]=a.frostSkier
 return textures,a.frostField,a.frostNotice.textValue,a.status.textValue
end
''')
raw=lua.eval('function(t,k) return rawget(t,k) end')
font=ImageFont.load_default(size=16)
def draw_scene(air):
    ts,field,notice,hud=lua.globals().frostPreview(air)
    image=Image.new('RGBA',(584,610),'#091a29')
    ImageDraw.Draw(image).rectangle((52,60,531,579),fill='#e0f2fa')
    textures=[t for t in ts.values() if t.shown and raw(t,'texture')]
    rank={'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3}
    textures.sort(key=lambda t:rank[t.layer])
    for t in textures:
        asset=Image.open(root/'FlightpathArcade/Media/Frost'/t.texture.split('\\')[-1]).convert('RGBA')
        uv=t.uv
        asset=asset.crop((round(uv[1]*asset.width),round(uv[3]*asset.height),round(uv[2]*asset.width),round(uv[4]*asset.height)))
        if asset.width==0 or asset.height==0:continue
        asset=asset.resize((round(t.width),round(t.height)),Image.Resampling.NEAREST)
        p=t.points[1]
        # Lua tables compare by identity through Lua, not Python proxy identity.
        same=lua.eval('function(a,b) return a==b end')(t.parent,field)
        x=(52 if same else 0)+round(p[4]);y=60-round(p[5])
        image.alpha_composite(asset,(x,y))
    d=ImageDraw.Draw(image)
    d.text((12,8),'FROST RUN / '+('AIR' if air else 'GROUND'),font=font,fill='#f5cf74')
    d.text((12,33),hud,font=font,fill='white')
    d.multiline_text((64,72),notice,font=font,fill='#80151a')
    d.text((12,587),'Partial trees remain visible; no pixels cross the field.',font=font,fill='#a4bcc8')
    return image
out=Image.new('RGB',(1208,680),'#102735');d=ImageDraw.Draw(out)
d.text((20,15),'Actual Lua draw-state illustration: boundary fixtures, not an in-game screenshot.',font=font,fill='white')
out.paste(draw_scene(False),(12,55));out.paste(draw_scene(True),(612,55))
(root/'dist').mkdir(exist_ok=True);out.save(root/'dist/FrostRun-clipping-preview.png')
print('Saved dist/FrostRun-clipping-preview.png')
