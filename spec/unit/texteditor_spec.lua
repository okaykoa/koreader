describe("TextEditor module", function()
    local TextEditor
    local _ = require("gettext")

    setup(function()
        require("commonrequire")
        disable_plugins()
        require("document/canvascontext"):init(require("device"))
    end)

    before_each(function()
        TextEditor = dofile("plugins/texteditor.koplugin/main.lua")
        TextEditor.settings = nil
    end)

    describe("saveAs", function()
        it("derives the starting folder from the path of the file being edited", function()
            local seen_path
            stub(TextEditor, "_showSaveAsDialog", function(_, new_path) seen_path = new_path end)
            TextEditor:saveAs("/mnt/us/notes/todo.txt")
            assert.equals("/mnt/us/notes/", seen_path)
            TextEditor._showSaveAsDialog:revert()
        end)

        it("does not read the editor's buffer until Save is pressed", function()
            local get_input_text = spy.new(function() return "buffer text" end)
            TextEditor.input = { getInputText = get_input_text, handleEvent = function() end }
            local captured
            stub(require("ui/uimanager"), "show", function(w) captured = w end)

            TextEditor:saveAs("/mnt/us/notes/todo.txt")
            assert.spy(get_input_text).was.called(0)

            stub(captured, "getInputText", function() return "/mnt/us/notes/todo.txt" end)
            stub(TextEditor, "saveFileContent", function() return true end)
            stub(TextEditor, "checkEditFile", function() end)
            captured.buttons[2][2].callback() -- "Save"

            assert.spy(get_input_text).was.called(1)
            assert.spy(TextEditor.saveFileContent).was.called_with(TextEditor, "/mnt/us/notes/todo.txt", "buffer text")

            require("ui/uimanager").show:revert()
            TextEditor.saveFileContent:revert()
            TextEditor.checkEditFile:revert()
        end)

        it("falls back to self.last_path when no file is currently being edited", function()
            local seen_path
            stub(TextEditor, "_showSaveAsDialog", function(_, new_path) seen_path = new_path end)
            TextEditor.input = nil
            TextEditor.last_path = "/mnt/us"
            TextEditor:saveAs(nil)
            assert.equals("/mnt/us/", seen_path)
            TextEditor._showSaveAsDialog:revert()
        end)
    end)

    describe("newFile", function()
        local function capturedInput()
            local captured
            stub(require("ui/uimanager"), "show", function(w) captured = w end)
            return function() return captured end
        end

        it("appends a trailing slash to a caller-provided folder that lacks one", function()
            local get_captured = capturedInput()
            TextEditor:newFile("/mnt/us/books", nil, true)
            assert.equals("/mnt/us/books/", get_captured().input)
            require("ui/uimanager").show:revert()
        end)

        it("leaves a caller-provided folder alone when it already ends in a slash", function()
            local get_captured = capturedInput()
            TextEditor:newFile("/mnt/us/books/", nil, true)
            assert.equals("/mnt/us/books/", get_captured().input)
            require("ui/uimanager").show:revert()
        end)

        it("falls back to self.last_path, normalized, when no path is given", function()
            local get_captured = capturedInput()
            TextEditor.settings = { readSetting = function() return nil end, has = function() return false end, nilOrTrue = function() return true end, isTrue = function() return false end }
            TextEditor.last_path = "/mnt/us"
            TextEditor:newFile(nil)
            assert.equals("/mnt/us/", get_captured().input)
            require("ui/uimanager").show:revert()
        end)

        it("does not touch a caller-provided file path when is_folder is not set", function()
            local get_captured = capturedInput()
            TextEditor:newFile("/mnt/us/notebook.txt")
            assert.equals("/mnt/us/notebook.txt", get_captured().input)
            require("ui/uimanager").show:revert()
        end)
    end)

    describe("showMenu", function()
        it("puts Save as first, followed by a separator, before the rotation buttons", function()
            local captured
            stub(require("ui/uimanager"), "show", function(w) captured = w end)
            TextEditor:showMenu("/mnt/us/notes.txt")
            assert.equals(_("Save as"), captured.buttons[1][1].text)
            assert.equals(0, #captured.buttons[2])
            assert.is_true(#captured.buttons > 2)
            require("ui/uimanager").show:revert()
        end)
    end)
end)
