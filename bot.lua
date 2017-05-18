tdcli = dofile('./tg/tdcli.lua')
serpent = (loadfile "./libs/serpent.lua")()
feedparser = (loadfile "./libs/feedparser.lua")()
our_id = 123456789 -- Put Here Your Bot ID
URL = require "socket.url"
http = require "socket.http"
https = require "ssl.https"
ltn12 = require "ltn12"

json = (loadfile "./libs/JSON.lua")()
mimetype = (loadfile "./libs/mimetype.lua")()
redis = (loadfile "./libs/redis.lua")()
JSON = (loadfile "./libs/dkjson.lua")()
local lgi = require ('lgi')

local notify = lgi.require('Notify')

notify.init ("Telegram updates")


chats = {}


function do_notify (user, msg)
  local n = notify.Notification.new(user, msg)
  n:show ()
end

function dl_cb (arg, data)
end

function serialize_to_file(data, file, uglify)
  file = io.open(file, 'w+')
  local serialized
  if not uglify then
    serialized = serpent.block(data, {
        comment = false,
        name = '_'
      })
  else
    serialized = serpent.dump(data)
  end
  file:write(serialized)
  file:close()
end

function load_data(filename)
	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)
	return data
end

function save_data(filename, data)
	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()
end

function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "banhammer",
	"banhammer-fa",
    "groupmanager",
	"groupmanager-fa",
    "msg-checks",
    "plugins",
    "tools",
    "expiretime",
    "mute-time",
    "del",
	"lock-fosh"

 },
    sudo_users = {123456789},
    admins = {},
    disabled_channels = {},
    moderation = {data = './data/moderation.json'},
    info_text = [[》permag.ir v3

🔰Our channel :
》@permag_bots《

🔰Our channel2 :
》@permag_ir《

🔰Our channel3 :
》@permag《

🔰Our website :
》http://permag.ir
]],
  }
  serialize_to_file(config, './data/config.lua')
  print ('saved config into conf.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: ./data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end
plugins = {}
_config = load_config()

function load_plugins()
  local config = loadfile ("./data/config.lua")()
      for k, v in pairs(config.enabled_plugins) do
        
        print("Loading Plugins", v)

        local ok, err =  pcall(function()
          local t = loadfile("plugins/"..v..'.lua')()
          plugins[v] = t
        end)

        if not ok then
          print('\27[31mError loading plugins '..v..'\27[39m')
        print(tostring(io.popen("lua plugins/"..v..".lua"):read('*all')))
            print('\27[31m'..err..'\27[39m')
        end
    end
end

function scandir(directory)
  local i, t, popen = 0, {}, io.popen
  for filename in popen('ls -a "'..directory..'"'):lines() do
    i = i + 1
    t[i] = filename
  end
  return t
end

function plugins_names( )
  local files = {}
  for k, v in pairs(scandir("plugins")) do
    -- Ends with .lua
    if (v:match(".lua$")) then
      table.insert(files, v)
    end
  end
  return files
end

-- Function name explains what it does.
function file_exists(name)
  local f = io.open(name,"r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function gp_type(chat_id)
  local gp_type = "pv"
  local id = tostring(chat_id)
    if id:match("^-100") then
      gp_type = "channel"
    elseif id:match("-") then
      gp_type = "chat"
  end
  return gp_type
end

function is_reply(msg)
  local var = false
    if msg.reply_to_message_id_ ~= 0 then -- reply message id is not 0
      var = true
    end
  return var
end

function is_supergroup(msg)
  chat_id = tostring(msg.chat_id_)
  if chat_id:match('^-100') then --supergroups and channels start with -100
    if not msg.is_post_ then
    return true
    end
  else
    return false
  end
end

function is_channel(msg)
  chat_id = tostring(msg.chat_id_)
  if chat_id:match('^-100') then -- Start with -100 (like channels and supergroups)
  if msg.is_post_ then -- message is a channel post
    return true
  else
    return false
  end
  end
end

function is_group(msg)
  chat_id = tostring(msg.chat_id_)
  if chat_id:match('^-100') then --not start with -100 (normal groups does not have -100 in first)
    return false
  elseif chat_id:match('^-') then
    return true
  else
    return false
  end
end

function is_private(msg)
  chat_id = tostring(msg.chat_id_)
  if chat_id:match('^-') then --private chat does not start with -
    return false
  else
    return true
  end
end

function check_markdown(text) --markdown escape ( when you need to escape markdown , use it like : check_markdown('your text')
		str = text
		if str:match('_') then
			output = str:gsub('_','\\_')
		elseif str:match('*') then
			output = str:gsub('*','\\*')
		elseif str:match('`') then
			output = str:gsub('`','\\`')
		else
			output = str
		end
	return output
end

function is_sudo(msg)
  local var = false
  -- Check users id in config
  for v,user in pairs(_config.sudo_users) do
    if user == msg.sender_user_id_ then
      var = true
    end
  end
  return var
end

function is_owner(msg)
  local var = false
  local data = load_data(_config.moderation.data)
  local user = msg.sender_user_id_
  if data[tostring(msg.chat_id_)] then
    if data[tostring(msg.chat_id_)]['owners'] then
      if data[tostring(msg.chat_id_)]['owners'][tostring(user)] then
        var = true
      end
    end
  end

  for v,user in pairs(_config.admins) do
    if user[1] == msg.sender_user_id_ then
      var = true
  end
end

  for v,user in pairs(_config.sudo_users) do
    if user == msg.sender_user_id_ then
        var = true
    end
  end
  return var
end

function is_admin(msg)
  local var = false
  local user = msg.sender_user_id_
  for v,user in pairs(_config.admins) do
    if user[1] == msg.sender_user_id_ then
      var = true
  end
end

  for v,user in pairs(_config.sudo_users) do
    if user == msg.sender_user_id_ then
        var = true
    end
  end
  return var
end

--Check if user is the mod of that group or not
function is_mod(msg)
  local var = false
  local data = load_data(_config.moderation.data)
  local usert = msg.sender_user_id_
  if data[tostring(msg.chat_id_)] then
    if data[tostring(msg.chat_id_)]['mods'] then
      if data[tostring(msg.chat_id_)]['mods'][tostring(usert)] then
        var = true
      end
    end
  end

  if data[tostring(msg.chat_id_)] then
    if data[tostring(msg.chat_id_)]['owners'] then
      if data[tostring(msg.chat_id_)]['owners'][tostring(usert)] then
        var = true
      end
    end
  end

  for v,user in pairs(_config.admins) do
    if user[1] == msg.sender_user_id_ then
      var = true
  end
end

  for v,user in pairs(_config.sudo_users) do
    if user == msg.sender_user_id_ then
        var = true
    end
  end
  return var
end

function is_owner1(chat_id, user_id)
  local var = false
  local data = load_data(_config.moderation.data)
  local user = user_id
  if data[tostring(chat_id)] then
    if data[tostring(chat_id)]['owners'] then
      if data[tostring(chat_id)]['owners'][tostring(user)] then
        var = true
      end
    end
  end

  for v,user in pairs(_config.admins) do
    if user[1] == user_id then
      var = true
  end
end

  for v,user in pairs(_config.sudo_users) do
    if user == user_id then
        var = true
    end
  end
  return var
end

function is_admin1(user_id)
  local var = false
  local user = user_id
  for v,user in pairs(_config.admins) do
    if user[1] == user_id then
      var = true
  end
end

  for v,user in pairs(_config.sudo_users) do
    if user == user_id then
        var = true
    end
  end
  return var
end

--Check if user is the mod of that group or not
function is_mod1(chat_id, user_id)
  local var = false
  local data = load_data(_config.moderation.data)
  local usert = user_id
  if data[tostring(chat_id)] then
    if data[tostring(chat_id)]['mods'] then
      if data[tostring(chat_id)]['mods'][tostring(usert)] then
        var = true
      end
    end
  end

  if data[tostring(chat_id)] then
    if data[tostring(chat_id)]['owners'] then
      if data[tostring(chat_id)]['owners'][tostring(usert)] then
        var = true
      end
    end
  end

  for v,user in pairs(_config.admins) do
    if user[1] == user_id then
      var = true
  end
end

  for v,user in pairs(_config.sudo_users) do
    if user == user_id then
        var = true
    end
  end
  return var
end

 function is_banned(user_id, chat_id)
  local var = false
  local data = load_data(_config.moderation.data)
  if data[tostring(chat_id)] then
    if data[tostring(chat_id)]['banned'] then
      if data[tostring(chat_id)]['banned'][tostring(user_id)] then
        var = true
      end
    end
  end
return var
end

 function is_silent_user(user_id, chat_id)
  local var = false
  local data = load_data(_config.moderation.data)
  if data[tostring(chat_id)] then
    if data[tostring(chat_id)]['is_silent_users'] then
      if data[tostring(chat_id)]['is_silent_users'][tostring(user_id)] then
        var = true
      end
    end
  end
return var
end

function is_gbanned(user_id)
  local var = false
  local data = load_data(_config.moderation.data)
  local user = user_id
  local gban_users = 'gban_users'
  if data[tostring(gban_users)] then
    if data[tostring(gban_users)][tostring(user)] then
      var = true
    end
  end
return var
end

function is_filter(msg, text)
local var = false
local data = load_data(_config.moderation.data)
  if data[tostring(msg.chat_id_)]['filterlist'] then
for k,v in pairs(data[tostring(msg.chat_id_)]['filterlist']) do 
    if string.find(string.lower(text), string.lower(k)) then
       var = true
        end
     end
  end
 return var
end

function kick_user(user_id, chat_id)
if not tonumber(user_id) then
return false
end
  tdcli.changeChatMemberStatus(chat_id, user_id, 'Kicked', dl_cb, nil)
end

function del_msg(chat_id, message_ids)
local msgid = {[0] = message_ids}
  tdcli.deleteMessages(chat_id, msgid, dl_cb, nil)
end

 function banned_list(chat_id)
local hash = "gp_lang:"..chat_id
local lang = redis:get(hash)
    local data = load_data(_config.moderation.data)
    local i = 1
  if not data[tostring(chat_id)] then
  if not lang then
    return '_Group is not added_'
else
    return 'گروه به لیست گروه های مدیریتی ربات اضافه نشده است'
   end
  end
  -- determine if table is empty
  if next(data[tostring(chat_id)]['banned']) == nil then --fix way
     if not lang then
					return "_No_ *banned* _users in this group_"
   else
					return "*هیچ کاربری از این گروه محروم نشده*"
              end
				end
       if not lang then
   message = '*List of banned users :*\n'
         else
   message = '_لیست کاربران محروم شده از گروه :_\n'
     end
  for k,v in pairs(data[tostring(chat_id)]['banned']) do
    message = message ..i.. '- '..v..' [' ..k.. '] \n'
   i = i + 1
end
  return message
end

 function silent_users_list(chat_id)
local hash = "gp_lang:"..chat_id
local lang = redis:get(hash)
    local data = load_data(_config.moderation.data)
    local i = 1
  if not data[tostring(chat_id)] then
  if not lang then
    return '_Group is not added_'
else
    return 'گروه به لیست گروه های مدیریتی ربات اضافه نشده است'
   end
  end
  -- determine if table is empty
  if next(data[tostring(chat_id)]['is_silent_users']) == nil then --fix way
        if not lang then
					return "_No_ *silent* _users in this group_"
   else
					return "*لیست کاربران سایلنت شده خالی است*"
             end
				end
      if not lang then
   message = '*List of silent users :*\n'
       else
   message = '_لیست کاربران سایلنت شده :_\n'
    end
  for k,v in pairs(data[tostring(chat_id)]['is_silent_users']) do
    message = message ..i.. '- '..v..' [' ..k.. '] \n'
   i = i + 1
end
  return message
end

 function gbanned_list(msg)
local hash = "gp_lang:"..msg.chat_id_
local lang = redis:get(hash)
    local data = load_data(_config.moderation.data)
    local i = 1
  if not data['gban_users'] then
    data['gban_users'] = {}
    save_data(_config.moderation.data, data)
  end
  if next(data['gban_users']) == nil then --fix way
    if not lang then
					return "_No_ *globally banned* _users available_"
   else
					return "*هیچ کاربری از گروه های ربات محروم نشده*"
             end
				end
        if not lang then
   message = '*List of globally banned users :*\n'
   else
   message = '_لیست کاربران محروم شده از گروه های ربات :_\n'
   end
  for k,v in pairs(data['gban_users']) do
    message = message ..i.. '- '..v..' [' ..k.. '] \n'
   i = i + 1
end
  return message
end

 function filter_list(msg)
local hash = "gp_lang:"..msg.chat_id_
local lang = redis:get(hash)
    local data = load_data(_config.moderation.data)
  if not data[tostring(msg.chat_id_)]['filterlist'] then
    data[tostring(msg.chat_id_)]['filterlist'] = {}
    save_data(_config.moderation.data, data)
    end
  if not data[tostring(msg.chat_id_)] then
  if not lang then
    return '_Group is not added_'
else
    return 'گروه به لیست گروه های مدیریتی ربات اضافه نشده است'
   end
  end
  -- determine if table is empty
  if next(data[tostring(msg.chat_id_)]['filterlist']) == nil then --fix way
      if not lang then
    return "*Filtered words list* _is empty_"
      else
    return "_لیست کلمات فیلتر شده خالی است_"
     end
  end
  if not data[tostring(msg.chat_id_)]['filterlist'] then
    data[tostring(msg.chat_id_)]['filterlist'] = {}
    save_data(_config.moderation.data, data)
    end
      if not lang then
       filterlist = '*List of filtered words :*\n'
         else
       filterlist = '_لیست کلمات فیلتر شده :_\n'
    end
 local i = 1
   for k,v in pairs(data[tostring(msg.chat_id_)]['filterlist']) do
              filterlist = filterlist..'*'..i..'* - _'..k..'_\n'
             i = i + 1
         end
     return filterlist
   end

function msg_valid(msg)
  if msg.date_ < os.time() - 60 then
    print('\27[36mOld msg\27[39m')
    return false
  end
  return true
end

function match_pattern(pattern, text, lower_case)
  if text then
    local matches = {}
    if lower_case then
      matches = { string.match(text:lower(), pattern) }
    else
      matches = { string.match(text, pattern) }
end
      if next(matches) then
        return matches
      end
  end
  -- nil
end
function match_plugin(plugin, plugin_name, msg)
    if plugin.pre_process then
        -- If plugin is for privileged users only
          local result = plugin.pre_process(msg)
          if result then
            print("pre process: ", plugin.plugin_name)
            --tdcli.sendMessage(receiver, msg.id_, 0, result, 0, "md")
          end
     end
  for k, pattern in pairs(plugin.patterns) do
     matches = match_pattern(pattern, msg.content_.text_)
    if matches then
        print("Message matches: ", pattern)
      if plugin.run then
        local result = plugin.run(msg, matches)
        if result then
            tdcli.sendMessage(msg.chat_id_, msg.id_, 0, result, 0, "md")
        end
      end
      return
    end
  end
end
_config = load_config()
load_plugins()
function tdcli_update_callback (data)
  if (data.ID == "UpdateNewMessage") then
--print(serpent.block(msg))
    local msg = data.message_

    local d = data.disable_notification_

    local chat = chats[msg.chat_id_]

    if redis:get('markread') == 'on' then
  tdcli.viewMessages(msg.chat_id_, {[0] = msg.id_}, dl_cb, nil)
    end

    if ((not d) and chat) then

      if msg.content_.ID == "MessageText" then

        do_notify (chat.title_, msg.content_.text_)

      else

        do_notify (chat.title_, msg.content_.ID)

      end

    end

if msg.content_.ID == "MessageText" then
      if msg_valid(msg) then
        msg.edited = false
        msg.pinned = false
        match_plugins(msg)
      end
    elseif msg.content_.ID == "MessagePinMessage" then
      local function pinned_cb(arg, data)
        msg = data
        msg.pinned = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, pinned_cb, nil)
elseif msg.content_.ID == "MessagePhoto" then
      local function photo_cb(arg, data)
        msg = data
        msg.photo_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, photo_cb, nil)
elseif msg.content_.ID == "MessageVideo" then
      local function video_cb(arg, data)
        msg = data
        msg.video_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, video_cb, nil)
elseif msg.content_.ID == "MessageAnimation" then
      local function gif_cb(arg, data)
        msg = data
        msg.animation_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, gif_cb, nil)
elseif msg.content_.ID == "MessageVoice" then
      local function voice_cb(arg, data)
        msg = data
        msg.voice_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, voice_cb, nil)
elseif msg.content_.ID == "MessageAudio" then
      local function audio_cb(arg, data)
        msg = data
        msg.audio_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, audio_cb, nil)
elseif msg.content_.ID == "MessageForwardedFromUser" then
      local function forward_cb(arg, data)
        msg = data
        msg.forward_info_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, forward_cb, nil)
elseif msg.content_.ID == "MessageSticker" then
      local function sticker_cb(arg, data)
        msg = data
        msg.sticker_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, sticker_cb, nil)
elseif msg.content_.ID == "MessageContact" then
      local function contact_cb(arg, data)
        msg = data
        msg.contact_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, contact_cb, nil)
elseif msg.content_.ID == "MessageDocument" then
      local function doc_cb(arg, data)
        msg = data
        msg.document_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, doc_cb, nil)
elseif msg.content_.ID == "MessageLocation" then
      local function loc_cb(arg, data)
        msg = data
        msg.location_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, loc_cb, nil)
elseif msg.content_.ID == "MessageGame" then
      local function game_cb(arg, data)
        msg = data
        msg.game_ = true
        match_plugins(msg)
      
    end
      tdcli_function ({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.id_
      }, game_cb, nil)
    elseif msg.content_.ID == "MessageChatAddMembers" then
				if msg_valid(msg) then
					for i=0,#msg.content_.members_ do
						msg.adduser = msg.content_.members_[i].id_
						match_plugins(msg)
					end
				end
		elseif msg.content_.ID == "MessageChatJoinByLink" then
				if msg_valid(msg) then
						msg.joinuser = msg.sender_user_id_
						match_plugins(msg)
				end
    elseif msg.content_.ID == "MessageChatDeleteMember" then
        if msg_valid(msg) then
          msg.deluser = true
          match_plugins(msg)
        end
    end
    if msg.content_.photo_ then
      --write_file("test.txt", vardump(msg))
      return false
    end

  elseif data.ID == "UpdateMessageEdited" then  
    local function edited_cb(arg, data)
        msg = data
        msg.edited = true
        match_plugins(msg)
      
    end
     tdcli_function ({
      ID = "GetMessage",
      chat_id_ = data.chat_id_,
      message_id_ = data.message_id_
    }, edited_cb, nil)
    
  elseif (data.ID == "UpdateChat") then

    chat = data.chat_

    chats[chat.id_] = chat

  elseif (data.ID == "UpdateOption" and data.name_ == "my_id") then

    tdcli_function ({ID="GetChats", offset_order_="9223372036854775807", offset_chat_id_=0, limit_=20}, dl_cb, nil)    

  end

end
-- http://permag.ir
-- @permag_ir
-- @permag_bots
-- @permag
