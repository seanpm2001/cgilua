----------------------------------------------------------------------------
-- $Id: main.lua,v 1.2 2003/11/07 14:47:10 tomas Exp $
--
-- CGILua "main" script
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- CGILua Libraries configuration
----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Load auxiliar functions defined in CGILua namespace (cgilua)
----------------------------------------------------------------------------
LUA_PATH = main_dir.."?.lua;"..lib_dir.."?.lua"
require"cgilua"

----------------------------------------------------------------------------
-- CGILua "security" configuration
---------------------------------------------------------------------------
--
-- copy 'map' information to CGILua namespace
--
cgilua.script_path = script_path

--
-- remove globals not to be accessed by CGILua scripts
-- 
cgilua.removeglobals{
	-- functions to be removed from the environment
	"execute",
}

--
-- Maximum "total" input size allowed (in bytes)
--
-- (total size of the incoming request data as defined by 
--    the metavariable CONTENT_LENGTH)
cgilua.setmaxinput(1024 * 1024) -- 1 MB

--
-- Maximum size for file upload (in bytes)
--   (can be redefined by 'env.lua' or a script,
--    but 'maxinput' is always checked first)
--
cgilua.setmaxfilesize(500 * 1024) -- 500 KB

--
-- Redefine require and loadlib
--
local function redefine_require ()
	local original_lib_dir = lib_dir
	local original_loadlib = loadlib
	_G.loadlib = nil
	local nova_loadlib = function (packagename, funcname)
		return original_loadlib (packagename, funcname)
	end
	local original_require = require
	_G.require = function (packagename)
		-- packagename cannot contain some special punctuation characters.
		assert (not (string.find (packagename, "[^%P%.%-]") or
				string.find (packagename, "%.%.")),
			"Package name cannot contain punctuation characters")
	
		_G.loadlib = nova_loadlib
		_G.LUA_PATH = original_lib_dir.."?.lua"
		original_require (packagename)
		_G.loadlib = nil
	end
end


----------------------------------------------------------------------------
-- Configure CGILua environment and execute the script
----------------------------------------------------------------------------

-- get the 'physical' directory of the script
cgilua.script_pdir, cgilua.script_file = cgilua.splitpath(cgilua.script_path)

-- check if CGILua handles this script type
local handler = cgilua.getscripthandler (cgilua.script_path)
if not handler then
	local path_info = os.getenv("PATH_INFO")
	if not path_info then
		error ("No script")
	end
	cgilua.redirect(cgilua.mkabsoluteurl(path_info))
else
	-- get the 'virtual' path of the script (PATH_INFO)
	cgilua.script_vpath = os.getenv("PATH_INFO")

	-- get the 'virtual' directory of the script
	--  (used to create URLs to scripts in the same 'virtual' directory)
	cgilua.script_vdir = cgilua.splitpath(os.getenv("PATH_INFO"))

	-- save the URL path to cgilua
	cgilua.urlpath = os.getenv("SCRIPT_NAME")

	-- parse the incoming request data
	cgi = {}
	if os.getenv("REQUEST_METHOD") == "POST" then
		cgilua.parsepostdata(cgi)
	end
	cgilua.parsequery(os.getenv("QUERY_STRING"),cgi)

	--LUA_PATH = lib_dir.."?"..lib_dir.."?.lua"
	redefine_require ()

	-- load application script.
	cgilua.pcall (cgilua.doif, appscript)

	-- change current directory to the script's "physical" dir
	dir.chdir(cgilua.script_pdir)

	-- set the script environment
	if type(userscriptname) == "string" then
		cgilua.pcall (cgilua.doif, cgilua.script_pdir..userscriptname)
	end

	cgilua.pcall (handler, cgilua.script_file)
	cgilua.close()				-- "close" function
end
