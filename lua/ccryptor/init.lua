local M = {}
local L = {}
local vim = vim

local function ends_with(str, ending)
    return ending == "" or str:sub(- #ending) == ending
end

M.setup = function(opts)
    if opts.dir_path == nil then
        error("setup function called but dir_path isn't specified")
    end

    if not ends_with(opts.dir_path, "/") then
        opts.dir_path = opts.dir_path .. "/"
    end

    vim.env.ccrypt_pass = nil

    M.Cfg = opts

    vim.api.nvim_create_autocmd("BufReadPost", {
        pattern = opts.dir_path .. "*",
        callback = L.read_pre_hook,
    })

    vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = opts.dir_path .. "*",
        callback = L.write_post_hook,
    })

    vim.api.nvim_create_autocmd("BufWinEnter", {
        pattern = opts.dir_path .. "*",
        callback = function()
            local current_buf = vim.api.nvim_get_current_buf()
            local filepath = vim.api.nvim_buf_get_name(current_buf)
            if vim.env.ccrypt_pass == nil and ends_with(filepath, ".cpt") then
                print("Password is wrong")
                vim.api.nvim_buf_delete(0, { force = true })
            end
        end,
    })
end

-- Took from https://stackoverflow.com/a/51893646/7256917 =>
-- https://gist.github.com/GabrielBdeC/b055af60707115cbc954b0751d87ec23
local function split(s, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(s, delimiter, from, true)
    while delim_from do
        if delim_from ~= 1 then
            table.insert(result, string.sub(s, from, delim_from - 1))
        end
        from = delim_to + 1
        delim_from, delim_to = string.find(s, delimiter, from, true)
    end
    if from <= #s then
        table.insert(result, string.sub(s, from))
    end
    return result
end

local function get_smallest_crypted_fle()
    -- Trying to get the smaller *.cpt file in directory
    local cmd = string.format(
        "!find %s -name \"*.cpt\" -exec ls -s {} + | sort -n | head -1 | awk '{print $2}'",
        M.Cfg.dir_path .. "*"
    )

    local ccryptor_smaller_filepath = vim.api.nvim_exec(cmd, true)
    ccryptor_smaller_filepath = split(ccryptor_smaller_filepath, "\n")

    if #ccryptor_smaller_filepath == 3 then
        return ccryptor_smaller_filepath[3]
    end

    if #ccryptor_smaller_filepath == 2 then
        -- There is no *.cpt files
        return nil
    end

    print(vim.inspect(ccryptor_smaller_filepath))
    error("Something went wrong")
end

local function handle_first_enter_to_ccrypt_dir()
    print(
        string.format(
            "This is your first ccryptor run for %s directory",
            M.Cfg.dir_path
        )
    )
    vim.cmd("let $ccrypt_pass1 = inputsecret('Enter a new ccrypt password: ')")
    vim.cmd("let $ccrypt_pass2 = inputsecret('Repeat the ccrypt password: ')")
    vim.api.nvim_exec("redraw | echo", false)
    if vim.env.ccrypt_pass1 ~= vim.env.ccrypt_pass2 then
        print("Error: Passwords are different")
        vim.api.nvim_buf_delete(0, { force = true })
        return
    else
        print("Password was successfully installed")
        vim.env.ccrypt_pass = vim.env.ccrypt_pass1
    end

end

-- returns data of decrypted file
local decrypt_file
decrypt_file = function(file_path, try_number)
    if try_number == 3 then
        vim.env.ccrypt_pass = nil
        return nil
    end

    if vim.env.ccrypt_pass == nil then
        vim.cmd("let $ccrypt_pass = inputsecret('Enter ccrypt password: ')")
    end

    local decrypted_text =
    vim.api.nvim_exec(string.format("!ccrypt -cb -E ccrypt_pass \"%s\"", file_path), true)
    decrypted_text = split(decrypted_text, "\n")
    table.remove(decrypted_text, 1)
    table.remove(decrypted_text, 1)

    if #decrypted_text > 1
        and string.find(decrypted_text[1], "key does not match") ~= nil
        and decrypted_text[#decrypted_text] == "shell returned 4"
    then
        vim.env.ccrypt_pass = nil
        return decrypt_file(file_path, try_number + 1)
    end
    return decrypted_text
end

L.write_post_hook = function()
    if vim.env.ccrypt_pass == nil then
        L.input_ccrypt_pass()
    end

    local current_buf = vim.api.nvim_get_current_buf()
    local filename_path = vim.api.nvim_buf_get_name(current_buf)
    local buf_text_before_encrypt = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
    vim.api.nvim_exec(string.format("!ccrypt -e -E ccrypt_pass \"%s\"", filename_path), true)
    local generated_file_path = filename_path .. ".cpt"
    if ends_with(generated_file_path, ".cpt.cpt") then
        vim.api.nvim_exec(string.format("!mv \"%s\" \"%s\"", generated_file_path, filename_path), true)
        vim.api.nvim_exec(string.format("e %s", filename_path), true)
    else
        -- This is first open of unencrypted file.
        -- After encryption we need to make sure that
        -- unencrypted file doesn't still exists
        vim.api.nvim_buf_delete(current_buf, { force = true })
        vim.api.nvim_exec(string.format("!rm \"%s\"", filename_path), true)

        vim.api.nvim_exec(string.format("e %s", generated_file_path), true)
        current_buf = vim.api.nvim_get_current_buf()
    end

    vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, buf_text_before_encrypt)
end

L.read_pre_hook = function()
    local current_buf = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(current_buf)

    if ends_with(filename, ".cpt") then
        vim.api.nvim_exec("setlocal noswapfile", false)

        local decrypted_text = decrypt_file(filename, 0)
        if decrypted_text == nil then
            return
        end
        vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, decrypted_text)
    else
        if vim.env.ccrypt_pass == nil then
            L.input_ccrypt_pass()
        end
    end
end

L.input_ccrypt_pass = function()
    local filepath = get_smallest_crypted_fle()
    if filepath == nil then
        handle_first_enter_to_ccrypt_dir()
    else
        local decrypted_text = decrypt_file(filepath, 0)
        if decrypted_text == nil then
            print("Password is wrong")
            vim.api.nvim_buf_delete(0, { force = true })
            return
        end
    end
end

return M
