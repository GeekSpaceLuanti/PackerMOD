local ui=dofile("mainmenu/lib/pmui/modern/init.lua")
local function window(w,h,scale)
    return {size={x=w*scale,y=h*scale},max_formspec_size={x=w/53.33,y=h/53.33},real_gui_scaling=scale}
end
describe("portable PMUI 2",function()
    it("configures every button family by type without per-screen CSS",function()
        local renderer=ui.new():configure("button",{["min-height"]=52,["font-size"]=18,["border-radius"]=12})
        for _,tag in ipairs({"button","key-button","toggle"})do
            local fs,meta=renderer:render{tree=ui.el(tag,{name="action",text="Run"})}
            assert.is_true(meta.tree.box.h>=52)
            assert.equal(18,meta.tree.style["font-size"])
            assert.is_truthy(fs:find("pmui_round_12",1,true))
        end
        assert.has_error(function()renderer:configure("button",{position="absolute"})end)
    end)
    it("renders typed selection, slider and named scrolling controls",function()
        local c=ui.components
        local rows={c.dropdown("choice",{"One","Two"},2),c.slider("volume",420)}
        for i=1,8 do rows[#rows+1]=c.button("row_"..i,"Row "..i)end
        local tree=ui.el("scroll",{name="pane",value=3,inline={["max-height"]=180}},rows)
        local fs,meta=ui.new():render{tree=tree}
        assert.is_true(meta.content_height<=180)
        assert.is_truthy(fs:find(";choice;One,Two;2;true]",1,true))
        assert.is_truthy(fs:find("horizontal;volume;420]",1,true))
        assert.is_truthy(fs:find(";pane;vertical;",1,true))
        assert.is_nil(fs:match("button%[[^%]]*;pane;"))
        assert.same({},ui.layout.validate(meta.tree))
    end)
    it("ships usable components and honors root CSS width without product code",function()
        local c=ui.components
        local tree=c.panel({c.tabs({{id="one",label="One",icon="box",count=0},{id="two",label="Two"}},"one"),
            c.empty{title="Start here",description="Create a world",action=c.button("create","Create",{class="primary",icon="plus"})}})
        local fs,result=ui.new():render{tree=tree,css=':root { max-width: 640px; }'}
        assert.equal(640,result.width)
        assert.same({},ui.layout.validate(result.tree))
        assert.is_truthy(fs:find("pmui_round_16",1,true))
        assert.is_truthy(fs:find(";create;",1,true))
    end)
    it("supports percentage spacing and stretches row peers",function()
        local tree=ui.el('div',{class='row'},{ui.el('p',{text='Short'}),ui.el('p',{text='Two\nlines'})})
        local _,result=ui.new():render{tree=tree,css='.row { padding: 5%; align-items: stretch; }'}
        assert.is_true(math.abs(result.width*0.05-result.tree.box.padding[1])<0.000001)
        assert.equal(result.tree.children[1].box.h,result.tree.children[2].box.h)
        assert.same({},ui.layout.validate(result.tree))
    end)
    it("loads and renders without PackerMOD, mainmenu globals or core",function()
        local p,c=_G.packermod,_G.core;_G.packermod=nil;_G.core=nil
        local ok,result=pcall(function()
            local api=dofile("mainmenu/lib/pmui/modern/init.lua")
            return api.new():render{html='<section class="panel"><p>${title}</p><button name="save" icon="save">Save</button></section>',
                context={title='World [one]; <script>'},css='.panel { padding: 24px; background: #18201C; border-radius: 16px; gap: 16px; } button { padding: 10px 16px; }'}
        end)
        _G.packermod=p;_G.core=c
        assert.is_true(ok,result)
        assert.is_truthy(result:find('World \\[one\\]\\; <script>',1,true))
        assert.is_truthy(result:find(';save;',1,true))
        assert.is_truthy(result:find('pmui_round_16.png',1,true))
    end)
    it("keeps CSS geometry unchanged across DPI scales",function()
        local tree=ui.el('section',{class='root'},{ui.el('p',{text='A world'}),ui.el('button',{name='start',text='Start',icon='play'})})
        local options={tree=tree,css='.root { padding: 24; gap: 16; } button { padding: 10 16; }',window=window(1100,800,1)}
        local _,a=ui.new():render(options);options.window=window(1100,800,2)
        local _,b=ui.new():render(options)
        assert.equal(a.width,b.width);assert.equal(a.content_height,b.content_height)
        assert.same({},ui.layout.validate(a.tree));assert.same({},ui.layout.validate(b.tree))
    end)
    it("applies variables, specificity and media queries before measuring",function()
        local css=':root { --space: 20px; } .row { flex-direction: row; gap: var(--space); } .row .item { width: 180px; } #special { width: 200px; } @media (max-width: 500px) { .row { gap: 8px; } }'
        local tree=ui.el('div',{class='row'},{ui.el('p',{class='item',text='one'}),ui.el('p',{class='item',id='special',text='two'})})
        local _,a=ui.new():render{tree=tree,css=css,window=window(450,600,1)}
        assert.equal(8,ui.styles.length(a.tree.style.gap,450));assert.equal(200,a.tree.children[2].box.w)
        assert.same({},ui.layout.validate(a.tree))
    end)
    it("wraps rows and text and scrolls only when required",function()
        local children={}
        for i=1,8 do children[#children+1]=ui.el('button',{name='action_'..i,text='Action '..i,class='item'}) end
        local tree=ui.el('div',{class='row'},children)
        local css='.row { flex-direction: row; flex-wrap: wrap; gap: 12; padding: 16; } .item { width: 150; height: 44; }'
        local fs,a=ui.new():render{tree=tree,css=css,window=window(340,200,1),scroll=99999}
        assert.is_true(a.scroll);assert.same({},ui.layout.validate(a.tree))
        assert.is_truthy(fs:find('scroll_container[',1,true))
        local _,b=ui.new():render{tree=tree,css=css,window=window(1200,800,1)}
        assert.is_false(b.scroll)
        assert.same({},ui.layout.validate(b.tree))
        assert.is_nil(tree.box) -- caller's tree is immutable
    end)
    it("rejects unsupported syntax instead of silently ignoring it",function()
        assert.has_error(function()ui.styles.parse('p { position: absolute; }')end)
        assert.has_error(function()ui.parse_html('<script>bad()</script>')end)
        assert.has_error(function()ui.parse_html('<button onclick="x">Run</button>')end)
        assert.has_error(function()ui.parse_html('<section><p>bad</section>')end)
    end)
    it("uses caller-provided font metrics and asset resolution",function()
        local calls=0
        local fs,a=ui.new{measure_text=function(text,font)calls=calls+1;return #text*font end,
            texture=function(name,color)return '/ui/'..name..(color or '')..'.png'end}:render{
                tree=ui.el('button',{name='go',text='Go',icon='play'}),css='button { padding: 12; background: #A0DFBB; border-radius: 8; }'}
        assert.is_true(calls>0);assert.is_true(a.tree.box.w>=50)
        assert.is_truthy(fs:find('/ui/round_8#A0DFBB.png',1,true))
    end)
end)
