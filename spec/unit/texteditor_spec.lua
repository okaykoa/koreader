describe("TextEditor module", function()
    local TextEditor

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
            local seen_path, seen_content
            stub(TextEditor, "_showSaveAsDialog", function(_, new_path, content)
                seen_path, seen_content = new_path, content
            end)
            TextEditor.input = { getInputText = function() return "buffer text" end }
            TextEditor:saveAs("/mnt/us/notes/todo.txt")
            assert.equals("/mnt/us/notes/", seen_path)
            assert.equals("buffer text", seen_content)
            TextEditor._showSaveAsDialog:revert()
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
end)
