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
end)
