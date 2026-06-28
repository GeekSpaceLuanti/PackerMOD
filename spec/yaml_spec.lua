package.path = "./?.lua;" .. package.path

local yaml = require("mainmenu.yaml")

describe("yaml.parse", function()
    it("parses a flat map", function()
        local r = yaml.parse("a: 1\nb: hello\nc: true\n")
        assert.are.same({ a = 1, b = "hello", c = true }, r)
    end)

    it("parses nested map", function()
        local r = yaml.parse("outer:\n  inner: 42\n  flag: false\n")
        assert.are.same({ outer = { inner = 42, flag = false } }, r)
    end)

    it("parses list of scalars", function()
        local r = yaml.parse("items:\n  - one\n  - two\n  - 3\n")
        assert.are.same({ items = { "one", "two", 3 } }, r)
    end)

    it("parses list of maps", function()
        local r = yaml.parse("mods:\n  - name: a\n    source: contentdb\n  - name: b\n    source: bundle\n")
        assert.are.same({
            mods = {
                { name = "a", source = "contentdb" },
                { name = "b", source = "bundle" },
            },
        }, r)
    end)

    it("parses literal block scalar", function()
        local r = yaml.parse('text: |\n  line one\n  line two\nflag: true\n')
        assert.are.equal("line one\nline two", r.text)
        assert.are.equal(true, r.flag)
    end)

    it("parses quoted strings preserving special chars", function()
        local r = yaml.parse('a: "1.0.0"\nb: \'true\'\n')
        assert.are.equal("1.0.0", r.a)
        assert.are.equal("true", r.b)
    end)

    it("ignores comments", function()
        local r = yaml.parse("# top comment\na: 1 # trailing\nb: 2\n")
        assert.are.same({ a = 1, b = 2 }, r)
    end)

    it("treats null/~/empty as nil", function()
        local r = yaml.parse("a: null\nb: ~\nc:\nd: 4\n")
        assert.is_nil(r.a)
        assert.is_nil(r.b)
        assert.is_nil(r.c)
        assert.are.equal(4, r.d)
    end)
end)

describe("yaml.dump", function()
    it("round-trips flat map", function()
        local input = { name = "foo", count = 3, on = true }
        local out = yaml.dump(input)
        assert.are.same(input, yaml.parse(out))
    end)

    it("round-trips list of maps", function()
        local input = {
            mods = {
                { name = "a", source = "contentdb", release = 100 },
                { name = "b", source = "bundle", path = "x/y" },
            },
        }
        assert.are.same(input, yaml.parse(yaml.dump(input)))
    end)

    it("quotes ambiguous strings", function()
        local out = yaml.dump({ v = "1.0.0", b = "true" })
        local parsed = yaml.parse(out)
        assert.are.equal("1.0.0", parsed.v)
        assert.are.equal("true", parsed.b)
    end)
end)
