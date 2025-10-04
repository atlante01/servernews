local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local S = core.get_translator(modname)

local news_file = modpath .. "/servernews.json"
local news_data = {}

local function save_news_data()
    local file = io.open(news_file, "w")
    if not file then core.log("error", "Unable to open servernews file for writing")
        return false
    end

    local servernews_string = core.write_json(news_data)

    file:write(servernews_string)
    file:close()

    return true
end

local function load_news_data()
    local file = io.open(news_file, "r")

    if not file then core.log("warning", "Servernews file not found, creating default")
        news_data = {
            {title = "Welcome", content = "It seems that some data is missing."},
            {title = "Rules", content = "It seems that some data is missing."},
            {title = "Updates", content = "It seems that some data is missing."}
        }

        save_news_data()
        return true
    end

    local content = file:read("*all")
    file:close()

    if not content or content == "" then core.log("error", "Servernews file is empty")
        news_data = {
            {title = "Error", content = "News file is corrupted. Using default data."}
        }
        return true
    end

    local success, data = pcall(core.parse_json, content)

    if not success then core.log("error", "Failed to parse servernews JSON")
        news_data = {
            {title = "Error", content = "Failed to parse news. Using default data."}
        }
        return true
    end

    news_data = data
    return true
end

local function get_titles_list()
    local titles = {}
    for i = 1, #news_data do
        if news_data[i] and news_data[i].title then
            titles[i] = news_data[i].title
        else
            titles[i] = "Untitled"
        end
    end
    return titles
end

local function validate_index(index)
    if type(index) ~= "number" then
        return false
    end
    if index < 1 or index > #news_data then
        return false
    end
    return true
end

local function build_formspec(selected_index)
    if not validate_index(selected_index) then
        selected_index = 1
    end

    local titles = get_titles_list()
    local textlist_items = table.concat(titles, ",")
    local content = ""

    if news_data[selected_index] then
        content = news_data[selected_index].content or ""
    end

    local formspec = "formspec_version[4]" ..
        "size[12,8]" ..
        "label[0.45,0.5;Server News]" ..
        "textlist[0.4,0.8;4,6.8;servernews_textlist;" .. textlist_items .. ";" .. selected_index .. ";false]" ..
        "textarea[4.6,1;7,5;;;" .. core.formspec_escape(content) .. "]" ..
        "button_exit[9.85,6.8;1.6,0.8;close;Done]"
    return formspec
end

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= modname .. ":menu" then
        return false
    end

    if fields.servernews_textlist then
        local event = core.explode_textlist_event(fields.servernews_textlist)
        if event.type == "CHG" then
            local selected = event.index
            if validate_index(selected) then
                core.show_formspec(player:get_player_name(), modname .. ":menu", build_formspec(selected))
            end
        end
    end
end)

core.register_on_newplayer(function(player)
    local player_name = player:get_player_name()

    if not load_news_data() then core.log("error", "Critical failure loading news data for new player: " .. player_name)
        return
    end

    if #news_data == 0 then core.log("warning", "No news available for new player: " .. player_name)
        return
    end

    core.show_formspec(player_name, modname .. ":menu", build_formspec(1))
end)

core.register_chatcommand("news", {
    description = S("Show server news"),
    func = function(player_name, param)
        local player = core.get_player_by_name(player_name)
        if not player then
            return false, S("Player not found")
        end

        if not load_news_data() then
            return false, S("Critical failure loading servernews data")
        end

        if #news_data == 0 then core.log("warning", "No servernews entries available")
            return false, S("No news available")
        end

        core.show_formspec(player_name, modname .. ":menu", build_formspec(1))

        return true, ""
    end,
})