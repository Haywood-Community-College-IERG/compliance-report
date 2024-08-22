-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
local List = require 'pandoc.List'

local site_path = "_site"
local site_indirect = "./"

local yaml_tagname = "accreditation"
local debug = "warning" -- can be blank or "error"

local root_dir = ""
local file_being_processed = ""
local file_being_processed_core = ""

local chapter_heading = ""
local chapter_heading_zero = ""
local chapter_heading_attr = ""

local artifact_target = "_blank"
local artifact_page = false

local sources_style = "Sources"
local sources_header = "Sources"
--local sources_path = "../documents"
local sources_path = "documents"
local sources_path_sub = "" 
local sources_path_core_sub = "" 
local sources_sorted = true
local sources_as_filename = false

local standards_path = "requirements"
local standards_target = false
local standards_core_suffix = ""

local link_to_artifact_style = "Link to Artifact"

local unitcode_style = "Unit Code"

local link_to_artifact_assessment_style = "Assessment"
local link_to_artifact_assessment_sep = "_"
local link_to_artifact_assessment_suffix = ""

local link_to_artifact_review_style = "Review"
local link_to_artifact_review_sep = "_"
local link_to_artifact_review_suffix = "_PR"

local link_to_artifact_job_prefix = "Job Description"
local link_to_artifact_job_prefix_sep = " - "
local link_to_artifact_job_suffix = ""
local link_to_artifact_job_suffix_sep = ""

local link_to_artifact_resume_prefix = "Resume"
local link_to_artifact_resume_prefix_sep = " - "
local link_to_artifact_resume_suffix = ""
local link_to_artifact_resume_suffix_sep = ""

local link_standard_style = "Link to Standard"

local hyperlink_style = "Hyperlink"
local hyperlink_evidence_path = ""
local replace_spaces = true

local judgment_style = "Judgment"

local sources_html_open = '<ul type="1">'
local sources_html_start = '<li>'
local sources_html_end = '</li>'
local sources_html_close = '</ul>'

local sources_pdf_open = '\n\\begin{enumerate}\n\\def\\labelenumi{\\arabic{enumi}.}\n\\itemsep1pt\\parskip0pt\\parsep0pt\n'
local sources_pdf_start = '\\item\n'
local sources_pdf_end = '\n'
local sources_pdf_close = '\\end{enumerate}\n\n'

local li_open = '<ul type="1">'
local li_start = '<li>'
local li_end = '</li>'
local li_close = '</ul>'

local qep_part_content = "QEP" --  "Impact Report of the Quality Enhancement Plan"
local qep_part_number = 99

local output_format = ""

local sources_list = pandoc.List() -- {}

local trace_options = { "link_to_artifact_style",
                        --"link_to_artifact_style:evidence_search",
                        --"link_to_artifact_style:sources_list",
                        "link_standard_style", 
                        "make_link",
                        --"hyperlink_style",
                        "add_to_sources",
                        --"unitcode_style",
                        --"isfile",
                        --"isdir",
                        -- "link_standard_style:evidence_search"
                        "sources_block",
                        -- "judgment_style",
                        -- "sources_style",
                        -- "DIV",
                        "LINK",
                        "SPAN",
                        --"IMAGE",
                        --"STR","PLAIN",
                        --"HEADER",
                        "HEADER 1",
                        --"HEADER 2",
                        "META",
                        -- "IZ",
                        --"DUMP",
                     }
                      
local core_standards = { "Standard 06.1", "Standard 08.1", "Standard 09.1", "Standard 09.2", "Standard 12.1" }

local function qldebug(opt, msg)
    if contains(trace_options, opt) and debug == "warning" then
        quarto.log.debug(yaml_tagname .. ": [" .. opt .. "]: " .. msg)
    end
end
                    
local function qlerror(opt, msg)
    if contains(trace_options, opt) and (debug == "warning" or debug == "error") then
        qldebug(opt, "(ERROR) " .. msg)
    end
end

function isfile(file)
    -- some error codes:
    -- 13 : EACCES - Permission denied
    -- 17 : EEXIST - File exists
    -- 20	: ENOTDIR - Not a directory
    -- 21	: EISDIR - Is a directory
    --
    qldebug("isfile", "    ...file: " .. file)
    local isok, errstr, errcode = os.rename(file, file)
    if isok == nil then
        if errcode == 13 then 
            -- Permission denied, but it exists
            return true
        end
        return false
    end
    return true
end

function isdir(dirpath)
    qldebug("isdir", "    ...dirpath: " .. dirpath)
    return isfile(dirpath .. "/")
end
                      
function contains(tbl, str)
    for _, value in pairs(tbl) do
        if value == str then
        return true
        end
    end
    return false
end

-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
--- Returns the type of a metadata value.
--
-- @param v a metadata value
-- @treturn string one of `Blocks`, `Inlines`, `List`, `Map`, `string`, `boolean`
local function metatype (v)
    if PANDOC_VERSION <= '2.16.2' then
        local metatag = type(v) == 'table' and v.t and v.t:gsub('^Meta', '')
        return metatag and metatag ~= 'Map' and metatag or type(v)
    end
    return pandoc.utils.type(v)
end

-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
local type = pandoc.utils.type or metatype


-- From https://github.com/nmfs-opensci/quarto_titlepages
local function dump(o)
    if type(o) == 'table' then
        qldebug("DUMP", "    ...table")
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        qldebug("DUMP", "    ...string")
        return tostring(o)
    end
end

-- Based on code from https://github.com/nmfs-opensci/quarto_titlepages
local function has_attr (tab, attr)
    for index, value in pairs(tab) do
        if index == attr then
            return true
        end
    end

    return false
end

-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
--- Returns a function which checks whether an object has the given ID.
local function has_id (id)
    return function(x) return x.id == id end
end


-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
--- Insert a named object into a list; if an object of the same name exists
-- already, add all properties only present in the new object to the existing
-- item.
function merge_on_id (list, namedObj)
    local elem, idx = list:find_if(has_id(namedObj.id))
    local res = elem and add_missing_entries(namedObj, elem) or namedObj
    local obj_idx = idx or (#list + 1)
    -- return res, obj_idx
    list[obj_idx] = res
    return res, #list
end


-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
-- Split a string at commas.
local function comma_separated_values(str)
    local acc = List:new{}
    for substr in str:gmatch('([^,]*)') do
        acc[#acc + 1] = substr:gsub('^%s*', ''):gsub('%s*$', '') -- trim
    end
    return acc
end

-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
--- Ensure the return value is a list.
local function ensure_list (val)
    if type(val) == 'List' then
        return val

    elseif type(val) == 'Inlines' then
        -- check if this is really a comma-separated list
        local csv = comma_separated_values(pandoc.utils.stringify(val))
        if #csv >= 2 then
            return csv
        end
        return List:new{val}

    elseif type(val) == 'table' and #val > 0 then
        return List:new(val)

    else
        -- Anything else, use as a singleton (or empty list if val == nil).
        return List:new{val}

    end
end

-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
--- Copy all key-value pairs of the first table into the second iff there is no
-- such key yet in the second table.
-- @returns the second argument
function add_missing_entries(a, b)
    for k, v in pairs(a) do
        b[k] = b[k] or v
    end
    return b
end

-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
--- Create an object with a name. The name is either taken directly from the
-- `name` field, or from the *only* field name (i.e., key) if the object is a
-- dictionary with just one entry. If neither exists, the name is left unset
-- (`nil`).
function to_named_object (obj)
    local named = {}
    if type(obj) == 'Inlines' then
        -- Treat inlines as the name
        named.name = obj
        named.id = pandoc.utils.stringify(obj)

    elseif type(obj) ~= 'table' then
        -- if the object isn't a table, just use its value as a name.
        named.name = pandoc.MetaInlines{pandoc.Str(tostring(obj))}
        named.id = tostring(obj)

    elseif obj.name ~= nil then
        -- object has name attribute → just create a copy of the object
        add_missing_entries(obj, named)
        named.id = pandoc.utils.stringify(named.id or named.name)

    elseif next(obj) and next(obj, next(obj)) == nil then
        -- Single-entry table. The entry's key is taken as the name, the value
        -- contains the attributes.
        key, attribs = next(obj)
        if type(attribs) == 'string' or type(attribs) == 'Inlines' then
            named.name = attribs
        else
            add_missing_entries(attribs, named)
            named.name = named.name or pandoc.MetaInlines{pandoc.Str(tostring(key))}
        end
        named.id = named.id and pandoc.utils.stringify(named.id) or key

    else
        -- this is not a named object adhering to the usual conventions.
        error('not a named object: ' .. tostring(obj))

    end

    return named
end

function insert_zero(prefix_str, str)
    if str == nil then
        str = prefix_str
        prefix_str = "Standard "
    end
    qldebug("IZ", "    ...IZ<-: [" .. prefix_str .. "], [" .. str .. "]")
    local num_str = string.match(str, "^" .. prefix_str .. "(%d+%.?%d*)")
    if num_str == nil then
        return str
    end
    local num = tonumber(num_str)
    if num == nil then
        return str
    end
    local int_part, dec_part = math.modf(num)
    local new_num_str = string.format("%02d", int_part)
    if dec_part ~= 0 then
        new_num_str = new_num_str .. string.sub(tostring(dec_part), 2)
    end
    rtn = string.gsub(str, num_str, new_num_str)
    qldebug("IZ", "    ...IZ->: [" .. rtn .. "]")
    return rtn
end
    
function make_link(path, evidence, evidence_pg, evidence_txt, processing_standard)
    qldebug("make_link", "    ...path: " .. path)
    qldebug("make_link", "    ...evidence: " .. evidence)
    qldebug("make_link", "    ...evidence_pg: " .. evidence_pg)
    qldebug("make_link", "    ...evidence_txt: " .. evidence_txt)
    local rtn_str = ""
    local loc_output_format = output_format

    local target_attr = "" -- {}

    if processing_standard==nil then
        processing_standard = false
    end

    evidence_txt = evidence_txt:gsub("%%20", " ")

    -- Create the link to the evidence file as markdown. This will replace the former text.
    if output_format == "html" then 
        if chapter_heading_attr~="" and artifact_target ~= "" and not processing_standard then 
            --target_attr = {target = artifact_target}
            target_attr = " target=\"" .. artifact_target .. "\""
        else
            target_attr = " target=\"_self\""
        end

        --rtn_str = pandoc.Link(evidence_txt, path .. evidence .. evidence_pg, evidence_txt, target_attr)
        rtn_str = "<a href=\"" .. path .. evidence .. evidence_pg .. "\" " .. target_attr .. " >" .. evidence_txt .. "</a>"

    elseif output_format == "pdf" or output_format == "latex" or output_format == "tex" then
        rtn_str = "\\href{" .. path .. evidence .. evidence_pg .. "}{{" .. evidence_txt .. "}}"
        --rtn_str = pandoc.Link(evidence_txt, path .. evidence .. evidence_pg, evidence_txt, {target = artifact_target})
        loc_output_format = "latex"
    else 
        rtn_str = "[" .. evidence_txt .. "](" .. path .. evidence .. evidence_pg .. ")"
        --rtn_str = pandoc.Link(evidence_txt, path .. evidence .. evidence_pg, evidence_txt)

    end

    qldebug("make_link", "    ...rtn_str: " .. dump(rtn_str))
    return rtn_str
    --return pandoc.RawInline(loc_output_format, rtn_str)
    
end

function add_to_sources2(sources_list, content, target, title)
    qldebug("add_to_sources", "Add to sources[content]: " .. content)
    qldebug("add_to_sources", "Add to sources[target]: " .. target)
    qldebug("add_to_sources", "Add to sources[title]: " .. title)

    local loc_link = pandoc.Inlines(pandoc.Link(pandoc.Str(content), target:gsub("%%20"," "), title))
    --local loc_link = pandoc.Link(pandoc.Str(content), target, title)

    -- Build up the list of sources. These will be managed below under the Sources Block
    if sources_sorted then
        local disp = nil
        if #sources_list == 0 then
            sources_list:insert(1, loc_link)
            --table.insert(sources_list, 1, loc_link)
            --table.insert(sources_list, 1, src)
            qldebug("add_to_sources", "    ...first table insert")
            disp = 1

        else
            for i = 1, #sources_list do
                if pandoc.utils.stringify(sources_list[i]) == pandoc.utils.stringify(loc_link) then
                    qldebug("add_to_sources", "    ...source already exists(" .. i .. ")")
                    disp = i
                    break

                elseif pandoc.utils.stringify(sources_list[i]) >= pandoc.utils.stringify(rtn_str) then
                    qldebug("add_to_sources", "    ...insert source(" .. i .. ")")
                    sources_list:insert(i, loc_link)
                    --table.insert(sources_list, i, loc_link)
                    disp = i
                    break

                --else
                --    qldebug("add_to_sources", "    ...CUR < EXIST(" .. i .. ")")

                end

            end

        end

        if disp == nil then
            qldebug("add_to_sources", "    ...append source")
            sources_list:insert(#sources_list + 1, loc_link)
            --table.insert(sources_list, #sources_list + 1, loc_link)
            disp = #sources_list

        end

    else
        qldebug("add_to_sources", "    ...append source")
        sources_list:insert(#sources_list + 1, loc_link)
        --table.insert(sources_list, #sources_list + 1, loc_link)

    end
    
end

function add_to_sources(sources_list, src)
    local loc_link = src -- pandoc.Link(pandoc.Str(src), src, "")
    local loc_link_str = li_start .. pandoc.utils.stringify(loc_link) .. li_end

    qldebug("add_to_sources", "Add to sources: " .. dump(loc_link))
    qldebug("add_to_sources", "Add to sources: " .. loc_link_str)

    -- Build up the list of sources. These will be managed below under the Sources Block
    if sources_sorted then
        local disp = nil
        local loc_sources_list_i = ""
        if #sources_list == 0 then
            table.insert(sources_list, 1, li_start .. loc_link .. li_end)
            --table.insert(sources_list, 1, src)
            qldebug("add_to_sources", "    ...first table insert: " .. dump(loc_link))
            disp = 1

        else
            for i = 1, #sources_list do
                loc_sources_list_i = pandoc.utils.stringify(sources_list[i])
                if loc_sources_list_i == loc_link_str then
                    qldebug("add_to_sources", "    ...source already exists(" .. i .. "): " .. loc_link_str)
                    disp = i
                    break

                elseif loc_sources_list_i > loc_link_str then
                    qldebug("add_to_sources", "    ...insert source(" .. i .. "): LS:" .. loc_link_str .. ", SL:" .. sources_list[i])
                    table.insert(sources_list, i, li_start .. loc_link .. li_end)
                    disp = i
                    break

                --else
                --    qldebug("add_to_sources", "    ...CUR < EXIST(" .. i .. "): SL:" .. sources_list[i])

                end

            end

        end

        if disp == nil then
            qldebug("add_to_sources", "    ...append source: " .. loc_link_str)
            table.insert(sources_list, #sources_list + 1, li_start .. loc_link .. li_end)
            disp = #sources_list

        end

    else
        qldebug("add_to_sources", "    ...append source: " .. loc_link_str)
        table.insert(sources_list, #sources_list + 1, li_start .. loc_link .. li_end)

    end
    
end

function link_to_artifact(el, artifact_type)
    qldebug("link_to_artifact_style", "Check Span: ")
    qldebug("link_to_artifact_style", "    ...content: " .. dump(el.content))
    qldebug("link_to_artifact_style", "    ...attributes: " .. dump(el.attr))
    -- qldebug("link_to_artifact_style", "    ...custom-style: " .. pandoc.utils.stringify(el_attr["custom-style"]))

    if pandoc.utils.stringify(el.content) == "" then 
        qldebug("link_to_artifact_style", "    ...empty content")
        return el
    end
    
    -- evidence_txt_orig contains the original text in the reference
    -- evidence_txt contains the text in the reference up to the section
    -- evidence_pg contains the section part of the reference
    -- evidence contains the actual reference after making corrections

    local evidence_txt_orig = pandoc.utils.stringify(el.content)
    local evidence_txt = string.gsub(insert_zero(evidence_txt_orig), "–", "-")
    local loc_output_format = output_format

    extension = ".pdf"
    evidence_pg = ""

    -- If the evidence has a page number, and artifact_page is true, 
    --     then construct the page number link
    pat = " - Page "
    idx = string.find(evidence_txt,pat,1,true)
    if idx ~= nil then
        if artifact_page then
            evidence_pg = "#page=" .. string.sub(evidence_txt,idx + string.len(pat))
        end

        -- Remove the page number from the evidence name
        evidence_txt = string.sub(evidence_txt, 1, idx - 1)

    end

    if artifact_type == "artifact" then
        evidence = evidence_txt .. extension
        sources_txt = evidence_txt
    elseif artifact_type == "assessment" then
        evidence = _G.unit_code .. link_to_artifact_assessment_sep .. evidence_txt .. link_to_artifact_assessment_suffix .. extension
        sources_txt = _G.unit_code .. link_to_artifact_assessment_sep .. evidence_txt .. link_to_artifact_assessment_suffix
    elseif artifact_type == "review" then
        evidence = _G.unit_code .. link_to_artifact_review_sep .. evidence_txt .. link_to_artifact_review_suffix .. extension
        sources_txt = _G.unit_code .. link_to_artifact_review_sep .. evidence_txt .. link_to_artifact_review_suffix
    elseif artifact_type == "job" then
        qldebug("link_to_artifact_style", "    [J]...evidence_txt: " .. evidence_txt)
        if link_to_artifact_job_prefix ~= "" then
            pref = link_to_artifact_job_prefix .. link_to_artifact_job_prefix_sep
        else 
            pref = ""
        end
        if link_to_artifact_job_suffix ~= "" then
            suf = link_to_artifact_job_suffix_sep .. link_to_artifact_job_suffix
        else
            suf = ""
        end
        evidence = pref .. evidence_txt .. suf .. extension
        sources_txt = evidence_txt
    elseif artifact_type == "resume" then
        qldebug("link_to_artifact_style", "    [R]...evidence_txt: " .. evidence_txt)
        qldebug("link_to_artifact_style", "    [R]...evidence_txt: " .. dump(evidence_txt))
        if link_to_artifact_resume_prefix ~= "" then
            pref = link_to_artifact_resume_prefix .. link_to_artifact_resume_prefix_sep
        else
            pref = ""
        end
        if link_to_artifact_resume_suffix ~= "" then
            suf = link_to_artifact_resume_suffix_sep .. link_to_artifact_resume_suffix
        else
            suf = ""
        end
        evidence = pref .. evidence_txt .. suf .. extension
        sources_txt = evidence_txt
    else
        qlerror("link_to_artifact_style", "Unknown artifact type (" .. artifact_type .. ")")
        return el
    end
    
    qldebug("link_to_artifact_style", "    ...evidence: ET[" .. evidence_txt .. "] - E[" .. evidence .. "]  -  EP[" .. evidence_pg .. "]")

    local dir_str = ""
    qldebug("link_to_artifact_style", "    ...dir_str(0): " .. dir_str)
    dir_str = root_dir .. "/".. sources_path
    qldebug("link_to_artifact_style", "    ...dir_str(0.1): " .. dir_str)
    if sources_path_sub ~= "" then
        if replace_spaces then
            dir_str = dir_str .. "/" .. sources_path_sub:gsub(" ", "-")
        else
            dir_str = dir_str .. "/" .. sources_path_sub
        end
    end
    qldebug("link_to_artifact_style", "    ...dir_str(0.2): " .. dir_str)
    dir_str = pandoc.path.normalize(  dir_str )
    qldebug("link_to_artifact_style", "    ...dir_str(1): " .. dir_str)
    dir_str = dir_str:gsub("\\","/")
    qldebug("link_to_artifact_style", "    ...dir_str(2): " .. dir_str)

    -- if sources_path_sub is in core_standards, then add the standards_core_suffix
    if contains(core_standards, sources_path_sub) then
        if sources_path_core_sub ~= "" then
            if replace_spaces then
                dir_str = dir_str .. standards_core_suffix:gsub(" ", "-")
            else
                dir_str = dir_str .. standards_core_suffix
            end
        end
        qldebug("link_to_artifact_style", "    ...dir_str(0.3): " .. dir_str)
        dir_str = pandoc.path.normalize(  dir_str )
        qldebug("link_to_artifact_style", "    ...dir_str(3): " .. dir_str)
        dir_str = dir_str:gsub("\\","/")
        qldebug("link_to_artifact_style", "    ...dir_str(4): " .. dir_str)
        if (not isdir(dir_str)) then
           qlerror("link_to_artifact_style", "Directory not found (" .. dir_str .. ")")
        end
    end
    files = pandoc.system.list_directory(dir_str)
    local fn = nil
    local loc_evidence = evidence 
    if replace_spaces then
        loc_evidence = loc_evidence:gsub(" ", "-")
        qldebug("link_to_artifact_style", "loc_evidence: " .. loc_evidence)
    end
    for _, file in ipairs(files) do 
        qldebug("link_to_artifact_style:evidence_search", "    ...dir: " .. file)
        if pandoc.utils.stringify(loc_evidence) == pandoc.utils.stringify(file) then 
            fn = file 
            qldebug("link_to_artifact_style:evidence_search", "    ...dir(fn): " .. loc_evidence)

        else
            qldebug("link_to_artifact_style:evidence_search", "    ...Not it - file: " .. file)

        end
    end
    if fn == nil then
        qlerror("link_to_artifact_style", "Evidence file not found (" .. chapter_heading .. " - " .. loc_evidence .. ")")
    end

    qldebug("link_to_artifact_style", "    ...evidence: " .. evidence_txt .. " - " .. loc_evidence .. "  -  " .. evidence_pg)
    if sources_as_filename then
        content = loc_evidence
    else
        content = sources_txt
    end

    qldebug("link_to_artifact_style", "    ...content: " .. content)
    src_path = sources_path .. "/"
    qldebug("link_to_artifact_style", "    ...src_path: " .. src_path) 
    if sources_path_sub ~= "" then
        src_path = src_path .. sources_path_sub 
        qldebug("link_to_artifact_style", "    ...src_path (1): " .. src_path) 
    end
    if contains(core_standards, sources_path_sub) then
        src_path = src_path .. standards_core_suffix
        qldebug("link_to_artifact_style", "    ...src_path (2): " .. src_path) 
    end
    src_path = src_path:gsub(" ", "-")
    if loc_output_format == "pdf" then
        src_path = site_indirect .. site_path .. "/" .. src_path  .. "/"
        qldebug("link_to_artifact_style", "    ...src_path (3): " .. src_path) 
        loc_output_format = "latex"
    end
    src_path = src_path .. "/"
    src_path = pandoc.path.normalize(  src_path )
    src_path = src_path:gsub("\\","/")
    if loc_output_format == "html" then
        src_path = "../" .. src_path
    end
    qldebug("link_to_artifact_style", "    ...src_path (4): " .. src_path) 
    rtn_str = make_link(src_path, loc_evidence, evidence_pg, evidence_txt)
    rtn_str_srcs = make_link(src_path, loc_evidence, evidence_pg, content)

    if loc_output_format == "latex" then
        rtn_str = rtn_str:gsub("_","\\_")
        rtn_str_srcs = rtn_str_srcs:gsub("_","\\_")
    end

    qldebug("link_to_artifact_style", "    ...rtn_str: " .. dump(rtn_str))
    qldebug("link_to_artifact_style", "    ...rtn_str_srcs: " .. dump(rtn_str_srcs))

    -- Add the evidence to the sources list
    add_to_sources(sources_list, rtn_str_srcs)
    --add_to_sources2(sources_list, content, src_path, evidence)
    qldebug("link_to_artifact_style:sources_list", "sources_list(" .. #sources_list .. "): " .. dump(sources_list))

    return pandoc.Span(pandoc.RawInline(loc_output_format, rtn_str))
end

function link_to_standard(el)
    local loc_standards_path = standards_path:gsub("\\","/") .. "/"

    -- evidence_txt_orig contains the original text in the reference
    -- evidence_txt contains the text in the reference up to the section
    -- evidence_pg contains the section part of the reference
    -- evidence contains the actual reference after making corrections

    local evidence_txt_orig = pandoc.utils.stringify(el.content)
    qldebug("link_standard_style", "    ...evidence_txt_orig: [" .. evidence_txt_orig .."]" )

    -- Replace the long dash from Word with a regular dash
    local evidence_txt = string.gsub(evidence_txt_orig, "–", "-")
    local evidence = ""
    local evidence_sec = ""
    local loc_chapter_heading_attr = ""
    local loc_output_format = output_format
    local loc_section_ref = ""

    -- Remove leading zeros in evidence text - that is, Standard 05.4 should become Standard 5.4
    evidence_txt = evidence_txt:gsub("Standard 0", "Standard ")
    qldebug("link_standard_style", "    ...evidence_txt: [" .. evidence_txt .."]" )

    pat = " - Section: "
    idx = string.find(evidence_txt,pat,1,true)
    if idx ~= nil then
        -- Sections are lowercase and use dashes for spaces ((.-)) in Quarto with no leading (^%s*) and trailing blanks (%s*$)
        evidence_sec = string.lower(string.sub(evidence_txt,idx + string.len(pat)))
        evidence_sec = string.gsub(evidence_sec:match("^%s*(.-)%s*$"), " ", "-")
    
        evidence_txt = string.sub(evidence_txt, 1, idx - 1)
    end

    evidence_txt_with_zero = insert_zero("Standard ", evidence_txt)

    qldebug("link_standard_style", "    ...evidence: ET[" .. evidence_txt .. "] - ETwZ[" .. evidence_txt_with_zero .. "] - E[" .. evidence .. "]  -  ES[" .. evidence_sec .. "]")

    loc_chapter_heading_attr = string.lower(evidence_txt:gsub(" ","-"))
    qldebug("link_standard_style", "    ...loc_chapter_heading_attr: [" .. loc_chapter_heading_attr .."]" )

    if output_format == "html" then 

        evidence = evidence_txt_with_zero
        if replace_spaces then
            evidence = evidence:gsub(" ", "-")
        end

        -- Convert the path to contain only /. 
        qpd = quarto.project.directory:gsub("\\","/")
        local usedir = (qpd .. "/" .. loc_standards_path .. "/"):gsub("\\","/"):gsub("//","/")
        qldebug("link_standard_style", "    ...quarto.project.directory: " .. qpd )
        qldebug("link_standard_style", "    ...loc_standards_path(1): [" .. loc_standards_path .."]" )

        -- If processing a Standard file, then set loc_standards_path to ""
        -- This is because Requirements.qmd is in the root folder and needs to redirect to the standards folder
        --    while a standard only needs to refer to the same folder.
        if chapter_heading_attr ~= "" then
            qldebug("link_standard_style", "    ...processing a standard" ) 
            loc_standards_path = ""
        end

        qldebug("link_standard_style", "    ...loc_standards_path(2): [" .. loc_standards_path .."]" )

        -- Check for existence of referenced standards file in the loc_standards_path directory.
        --files = pandoc.system.list_directory(quarto.project.directory .. "/" .. standards_path)
        qldebug("link_standard_style", "    ...searching folder: " .. usedir)
        files = pandoc.system.list_directory(usedir)
        local fn = nil

        local loc_standards_core_suffix = standards_core_suffix
        if replace_spaces then
            loc_standards_core_suffix = loc_standards_core_suffix:gsub(" ", "-")
        end
        qldebug("link_standard_style", "    ...Looking for standard file: [" .. evidence .. ".qmd]  -  [" .. evidence .. loc_standards_core_suffix .. ".qmd]")

        for _, file in ipairs(files) do 
            qldebug("link_standard_style:evidence_search", "    ...file: [" .. file .. "]")
            if (evidence .. ".qmd" == file) or (evidence .. loc_standards_core_suffix .. ".qmd" == file) then 
                fn = file 
                qldebug("link_standard_style:evidence_search", "    ...fn: [" .. fn .. "]")
                break

            else
                qldebug("link_standard_style:evidence_search", "    ...Not it - file: [" .. file .. "]")

            end

        end

        if fn == nil then
            qlerror("link_standard_style", "Standard file not found (" .. chapter_heading .. " - " .. evidence .. ")")
        else
            evidence = fn
            -- remove .qmd suffix
            evidence = string.sub(evidence, 1, #evidence - 4)
            qldebug("link_standard_style", "    ...Found evidence file [" .. evidence .. "]")

        end

        if evidence_sec ~= "" then
            loc_section_ref = "#" .. evidence_txt:lower() .. "--" .. evidence_sec
            loc_section_ref = loc_section_ref:gsub(" ", "-")
        end

        evidence = evidence .. ".html"
        rtn_str = make_link(loc_standards_path, evidence, loc_section_ref, evidence_txt, true)

    elseif output_format == "pdf" or output_format == "latex" then
        loc_output_format = "latex"
        if evidence_sec ~= "" then
            loc_chapter_heading_attr = loc_chapter_heading_attr .. "--" .. evidence_sec
            loc_chapter_heading_attr = loc_chapter_heading_attr:gsub(" ", "-")
        end
        --rtn_str = make_link("", loc_chapter_heading_attr, "", evidence_txt)
        rtn_str = "\\hyperref[" .. loc_chapter_heading_attr .. "]{" .. evidence_txt .. "}"
        
    else -- native
        rtn_str = "[" .. evidence_txt .. "](" .. loc_chapter_heading_attr .. ")"
    end

    qldebug("link_standard_style", "    ...rtn_str: " .. dump(rtn_str))
    --return pandoc.RawInline(output_format, rtn_str)
    return pandoc.Span(pandoc.RawInline(loc_output_format, rtn_str))

end

local filter = {
    traverse = 'topdown',

    Meta = function(m)
        if quarto.doc.is_format("html") then
            li_start = sources_html_start
            li_end = sources_html_end
            li_open = sources_html_open
            li_close = sources_html_close
            output_format = "html"
            qldebug("META", "Check Meta - html")
        elseif quarto.doc.is_format("pdf") then
            li_start = sources_pdf_start
            li_end = sources_pdf_end
            li_open = sources_pdf_open
            li_close = sources_pdf_close
            output_format = "pdf"
            qldebug("META", "Check Meta - pdf")
        else
            qldebug("META", "Check Meta - unknown")
        end        

        -- qldebug("META", "Check Meta: " .. dump(m))
        local accreditation_meta = ensure_list(m[yaml_tagname]):map(to_named_object)

        root_dir = quarto.project.directory
        file_being_processed = pandoc.path.filename(quarto.doc.input_file)
        --qldebug("META", "File Details - input_file            : " .. quarto.doc.input_file)
        qldebug("META", "File Details - file_being_processed    : " .. file_being_processed)
        qldebug("META", "File Details - root_dir                : " .. root_dir)
        --qldebug("META", "File Details - quarto.project.offset   : " .. quarto.project.offset)
        --qldebug("META", "File Details - quarto.project.directory: " .. quarto.project.directory)
        
        sources_path_sub, _ = pandoc.path.split_extension(pandoc.path.filename(quarto.doc.input_file))
        qldebug("META", "Check Meta - fn (sources_path_sub): " .. sources_path_sub)

        for _, sub_attr in ipairs(accreditation_meta) do 
            qldebug("META", "Check Meta - sources name: " .. dump(sub_attr))

            -- Handle the non-specific YAML attributes first
            if sub_attr.id == "target" then
                artifact_target = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - target: " .. artifact_target)

            elseif sub_attr.id == "page" then
                artifact_page = pandoc.utils.stringify(sub_attr.name) == "true"
                qldebug("META", "Check Meta - page: " .. pandoc.utils.stringify(artifact_page))

            elseif sub_attr.id == "qep_part_content" then
                qep_part_content = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - qep_part_content: " .. qep_part_content)

            elseif sub_attr.id == "qep_part_number" then
                qep_part_number = math.floor(tonumber(pandoc.utils.stringify(sub_attr.name)) or error("Could not cast '" .. tostring(pandoc.utils.stringify(sub_attr.name)) .. "' to number.'"))
                qldebug("META", "Check Meta - qep_part_number: " .. qep_part_number)

            -- Handle SOURCES YAML attributes
            elseif sub_attr.id == "sources_style" then
                sources_style = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - sources style: " .. sources_style)

            elseif sub_attr.id == "sources_header" then
                sources_header = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - sources name: " .. sources_header)

            elseif sub_attr.id == "sources_path" then
                sources_path = pandoc.path.make_relative(pandoc.utils.stringify(sub_attr.name), quarto.doc.input_file)
                qldebug("META", "Check Meta - sources path: " .. sources_path)

            elseif sub_attr.id == "sources_sorted" then
                sources_sorted = (pandoc.utils.stringify(sub_attr.name) == "true")
                qldebug("META", "Check Meta - sources path: " .. pandoc.utils.stringify(sources_sorted))

            elseif sub_attr.id == "sources_as_filename" then
                sources_as_filename = (pandoc.utils.stringify(sub_attr.name) == "true")
                qldebug("META", "Check Meta - sources_as_filename: " .. pandoc.utils.stringify(sources_as_filename))

            -- Handle LINK YAML attributes
            elseif sub_attr.id == "link_to_artifact_style" then
                link_to_artifact_style = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - link_to_artifact_style: " .. link_to_artifact_style)

            elseif sub_attr.id == "link_standard_style" then
                link_standard_style = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - link_standard_style: " .. link_standard_style)

            elseif sub_attr.id == "standards_path" then
                standards_path = pandoc.path.make_relative(pandoc.utils.stringify(sub_attr.name), quarto.doc.input_file)
                qldebug("META", "Check Meta - standards_path: " .. standards_path)

            elseif sub_attr.id == "standards_target" then
                standards_target = (pandoc.utils.stringify(sub_attr.name) == "true")
                qldebug("META", "Check Meta - standards_target: " .. pandoc.utils.stringify(standards_target))

            elseif sub_attr.id == "standards_core_suffix" then
                standards_core_suffix = pandoc.utils.stringify(sub_attr.name)
                standards_core_suffix = standards_core_suffix:gsub("{(.+)}", "%1")
                qldebug("META", "Check Meta - standards_core_suffix: " .. standards_core_suffix)
            
            -- Handle assessment and review path
            elseif sub_attr.id == "sources_path" then
                sources_path = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - sources_path: " .. sources_path)

            -- Handle JUDGMENT YAML attributes
            elseif sub_attr.id == "judgment_style" then
                judgment_style = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - judgment_style: " .. judgment_style)

            elseif sub_attr.id == "link_to_artifact_job_prefix" then
                link_to_artifact_job_prefix = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - link_to_artifact_job_prefix: " .. link_to_artifact_job_prefix)

            elseif sub_attr.id == "link_to_artifact_job_prefix_sep" then             
                link_to_artifact_job_prefix_sep = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - link_to_artifact_job_prefix_sep: " .. link_to_artifact_job_prefix_sep)

            elseif sub_attr.id == "link_to_artifact_job_suffix" then
                link_to_artifact_job_suffix = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - link_to_artifact_job_suffix: " .. link_to_artifact_job_suffix)

            elseif sub_attr.id == "link_to_artifact_resume_prefix" then
                link_to_artifact_resume_prefix = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - link_to_artifact_resume_prefix: " .. link_to_artifact_resume_prefix)

            elseif sub_attr.id == "link_to_artifact_resume_prefix_sep" then
                link_to_artifact_resume_prefix_sep = pandoc.utils.stringify(sub_attr.name)
                qldebug("META", "Check Meta - link_to_artifact_resume_prefix_sep: " .. link_to_artifact_resume_prefix_sep)

                --hyperlink_evidence_path
            elseif sub_attr.id == "hyperlink_evidence_path" then
                hyperlink_evidence_path = pandoc.utils.stringify(sub_attr.name):lower()
                --hyperlink_evidence_path = hyperlink_evidence_path:lower()
                qldebug("META", "Check Meta - hyperlink_evidence_path: " .. hyperlink_evidence_path)

            elseif sub_attr.id == "replace_spaces" then
                replace_spaces = (pandoc.utils.stringify(sub_attr.name) == "true")
                qldebug("META", "Check Meta - replace_spaces: " .. pandoc.utils.stringify(replace_spaces))
                
            end
        end

        if artifact_page then
            pandoc.system.make_directory(site_path .. "/" .. sources_path .. "/" .. sources_path_sub, true)
        end

        return m
    end,

    Header = function(el)

        if (el.level == 1) then
            el_content = pandoc.utils.stringify(el.content)
            qldebug("HEADER 1", "    ...content: " .. el_content)

            -- If el_content starts with "Standard ", then it is a standard
            if string.find(el_content, "Standard ", 1, true) then
                qldebug("HEADER 1", "    ...Standard")
                qldebug("HEADER 1", "    ...attr: " .. dump(el.attr))
                el_content_zero = insert_zero("Standard ", el_content)
                qldebug("HEADER 1", "    ...content_zero: " .. el_content_zero)
                chapter_heading = el_content
                chapter_heading_zero = el_content_zero
                chapter_heading_attr = string.lower(chapter_heading_zero:gsub(" ", "-"))
                chapter_heading_attr = string.gsub(chapter_heading_attr, "-0", "-")

                file_being_processed = el_content_zero .. ".qmd"
                file_being_processed_core = el_content_zero .. standards_core_suffix .. ".qmd"
                sources_path_sub = el_content_zero
                sources_path_core_sub = el_content_zero .. standards_core_suffix
            else
                qldebug("HEADER 1", "Not a Standard Header")
                el_content_zero = ""
                chapter_heading = ""
                chapter_heading_zero = ""
                chapter_heading_attr = ""

                file_being_processed = ""
                file_being_processed_core = ""
                sources_path_sub = ""
                sources_path_core_sub = ""
            end

            sources_list = pandoc.List()

            if output_format == "pdf" or output_format == "latex" then
                qldebug("HEADER 1", "    ...Processing latex")
                -- Need to inject the setcounter command here if the header is for the QEP
                if el_content == qep_part_content then
                    qldebug("HEADER 1", "    ...QEP setcounter")
                    -- local el_content_tbl = el.content
                    -- table.insert(el_content_tbl, 1, pandoc.RawInline("latex", "\\setcounter{part}{4} % From Lua\n"))
                    -- qldebug("HEADER 1", "    ...el_content_tbl : " .. dump(el_content_tbl))

                    el = pandoc.RawInline("latex", "\\setcounter{part}{" .. qep_part_number -1 .. "} % From Lua\n\\part{" .. qep_part_content .. "}")
                end
            end

            qldebug("HEADER 1", "    ...file_being_processed  : " .. file_being_processed)
            qldebug("HEADER 1", "    ...fn (sources_path_sub) : " .. sources_path_sub)
            qldebug("HEADER 1", "    ...chapter_heading_zero  : " .. chapter_heading_zero)
            qldebug("HEADER 1", "    ...chapter_heading_attr  : " .. chapter_heading_attr)

            qldebug("HEADER 1", "    ...el (return)  : " .. dump(el))

            return el

        elseif (el.level == 2 or el.level == 3) then 
            el_content = pandoc.utils.stringify(el.content)

            -- If chapter_heading is not blank, then we are processing a standard
            -- If so, make all the level 2 links have a reference target include the standard #
            if chapter_heading ~="" then
                qldebug("HEADER 2", "    ...Level 2 in Standard")
                qldebug("HEADER 2", "    ...attr: " .. dump(el.attr))

                if chapter_heading_attr ~= "" then
                    el.identifier = chapter_heading_attr .. "--" .. el.identifier
                    -- remove from el.identifier the - followed by a number that is appended to the identifier
                    el.identifier = string.gsub(el.identifier, "-%d+$", "")
                    qldebug("HEADER 2", "    ...el.identifier: " .. el.identifier)
                end
                return el
            end 
        end
        return el
    end,

    Image = function(el)
        qldebug("IMAGE", "    ...el: " .. dump(el))
        -- replace the '.' with the root_dir
        el.src = pandoc.path.normalize( root_dir .. "/" .. el.src )
        -- remove standards_path from the el.src
        el.src = string.gsub(el.src, standards_path, "")
        qldebug("IMAGE", "    ...el.src: " .. el.src)
        return el
    end,

    Link = function(el)
        el_attr = el.attributes 
        el_content = el.content
        el_target = el.target
        --el_title = el.title
        --el_attributes = el.attributes
        qldebug("LINK", "    ...metatype: " .. metatype(el_content))
        qldebug("LINK", pandoc.utils.stringify(el.content) .. "  -  " .. dump(el_attr) )
        qldebug("LINK", "    ...el_target: " .. el_target)
        qldebug("LINK", "    ...el_content: " .. dump(el_content))
        --qldebug("LINK", "    ...el_title: " .. el_title)
        --qldebug("LINK", "    ...el_attributes: " .. dump(el_attributes))

        if el.content[1].tag == "Span" and el.content[1].attributes["custom-style"] == "Hyperlink" then
            qldebug("LINK", "    ...Hyperlink: " .. dump(el.content[1].attributes))
            qldebug("LINK", "    ...hyperlink_evidence_path: " .. hyperlink_evidence_path)

            -- First, find the hyperlink_evidence_path in the target. 
            -- NOTE: It may appear there more than once -- we want the first one.
            -- NOTE: The search is case-insensitive, so convert everything to lower case first.
            idx, endpos = (el_target:lower()):find(hyperlink_evidence_path:lower(), 1, true)
            if idx ~= nil then
                qldebug("LINK", "    ...idx: " .. idx .. "  -  " .. endpos)
                --el_target = string.sub(el_target, 1, idx - 1)
                --el_target_part1 = el_target:sub(1, idx - 1)
                el_target = el_target:sub(endpos + 1, el_target:len())
            else
                qlerror("LINK", "Hyperlink Evidence Path not found in target (" .. chapter_heading .. " - " .. pandoc.utils.stringify(el.content) .. " -- " .. el_target .. ")")
            end
            qldebug("LINK", "    ...el_target(1): " .. el_target)

            -- el_target should start with the folder where the artifact lives
            -- It is optionally followed by a question mark or an ampersand and other stuff -- remove that
            idx, endpos = el_target:find("?", 1, true)
            if idx ~= nil then
                qldebug("LINK", "    ...idx: " .. idx .. "  -  " .. endpos)
                el_target = el_target:sub(1, idx - 1)
            end
            qldebug("LINK", "    ...el_target(2): " .. el_target)
            idx, endpos = el_target:find("&", 1, true)
            if idx ~= nil then
                qldebug("LINK", "    ...idx: " .. idx .. "  -  " .. endpos)
                el_target = el_target:sub(1, idx - 1)
            end

            qldebug("LINK", "    ...el_target(3): " .. el_target)
            -- If replace_spaces is true, then replace spaces with -
            -- first, save el_target for later use
            el_target_content = el_target
            if replace_spaces then
                el_target = el_target:gsub(" ", "-")
                el_target = el_target:gsub("%%20", "-")
            end
            qldebug("LINK", "    ...el_target(4): " .. el_target)

            -- Use the raw target to make a link for Sources

            -- Now fix the target to include the sources path
            qldebug("LINK", "    ...sources_path - sub: " .. sources_path .. "  -  " .. sources_path_sub)
            el_target = sources_path .. "/" .. el_target

            if output_format == "html" then
                el_target = "../" .. el_target
            elseif output_format == "pdf" then
                el_target = site_indirect .. site_path .. "/" .. el_target
            end
            el_target = el_target:gsub("//", "/")
            qldebug("LINK", "    ...el_target(5): " .. el_target)
        
            if sources_as_filename then
                content = el_target_content:match("/([^/]+)$")
            else
                content = pandoc.utils.stringify(el.content)
            end
            qldebug("LINK", "    ...content: " .. content)
            idx, endpos = content:find(".pdf", 1, true)
            if idx ~= nil then
                qldebug("LINK", "    ...idx: " .. idx .. "  -  " .. endpos)
                content = content:sub(1, idx - 1)
            end

            rtn_str = make_link("", el_target, "", content)
            -- rtn_str = make_link(sources_path .. "/", el.target, "", content)

            if output_format == "pdf" or output_format == "latex" then
                rtn_str = rtn_str:gsub("_","\\_")
            end
            --rtn_str = "[" .. pandoc.utils.stringify(el.content) .. "](" .. el.target .. ")"
            qldebug("LINK", "rtn_str: " .. dump(rtn_str))
            add_to_sources(sources_list, rtn_str)

            -- Now, save the new target
            el.target = el_target

            --return pandoc.Span(pandoc.RawInline(output_format, rtn_str), pandoc.Attr("",{},{{"custom-style","Hyperlink"}}))
            return el
        end

    end,

    Span = function(el)

        el_attr = el.attributes 

        qldebug("SPAN", pandoc.utils.stringify(el.content) .. "  -  " .. dump(el_attr) )

        -- The tables that pandoc generates from the Docx to Md conversion use the data-custom-style attribute
        --    instead of the custom-style attribute. This is a workaround to handle that.
        if has_attr(el_attr, "custom-style") or has_attr(el_attr, "data-custom-style") then

            if has_attr(el_attr, "custom-style") then
                custom_style = pandoc.utils.stringify(el_attr["custom-style"])
            else
                custom_style = pandoc.utils.stringify(el_attr["data-custom-style"])
            end

            --- Handle Unit Code Style
            --- This captures the unit code for later use
            if custom_style == unitcode_style then
                -- Save the unit code for later use
                _G.unit_code = pandoc.utils.stringify(el.content)
                -- Check for preceeding and trailing square brackets and remove them
                if string.sub(_G.unit_code, 1, 1) == "[" then
                    _G.unit_code = string.sub(_G.unit_code, 2, #_G.unit_code - 1)
                end
                qldebug("unitcode_style", "    ...unit_code: " .. _G.unit_code)
                return pandoc.Span(pandoc.RawInline(output_format,""))
        
            --- Handle LINKs to artifacts
            elseif custom_style == link_to_artifact_style then
                qldebug("link_to_artifact_style", "Link to Artifact")
                return link_to_artifact(el, "artifact")

            elseif custom_style == (link_to_artifact_style .. " - " .. link_to_artifact_assessment_style) then
                qldebug("link_to_artifact_style", "    ...unit_code: " .. _G.unit_code .. "  [A] -  " .. pandoc.utils.stringify(el.content))
                return link_to_artifact(el, "assessment")

            elseif custom_style == (link_to_artifact_style .. " - " .. link_to_artifact_review_style) then
                qldebug("link_to_artifact_style", "    ...unit_code: " .. _G.unit_code .. "  [R] -  " .. pandoc.utils.stringify(el.content))
                return link_to_artifact(el, "review")

            elseif custom_style == (link_to_artifact_style .. " - " .. link_to_artifact_job_prefix) then
                qldebug("link_to_artifact_style", " [J] -  " .. pandoc.utils.stringify(el.content))
                return link_to_artifact(el, "job")

            elseif custom_style == (link_to_artifact_style .. " - " .. link_to_artifact_resume_prefix) then
                qldebug("link_to_artifact_style", " [R] -  " .. pandoc.utils.stringify(el.content))
                return link_to_artifact(el, "resume")

                --- Handle LINKs to standards
            elseif custom_style == link_standard_style then
                qldebug("link_standard_style", "Link to Standards")
                return link_to_standard(el)

            --- Handle SOURCES Style
            elseif custom_style == sources_style then
                qldebug("sources_block", "Sources Block")
                qldebug("sources_block", "    ...el: " .. dump(el))

                if #sources_list == 0 then
                    qldebug("sources_block", "    ...sources_list is empty")
                    return pandoc.Span("No sources found.")
                end
                local loc_source = pandoc.utils.stringify(sources_list)
                local loc_output_format = output_format
                local bl = li_open .. loc_source .. li_close
                qldebug("sources_block", "    ...bl: " .. dump(bl))

                if output_format == "pdf" or output_format == "latex" then
                    loc_output_format = "latex"
                else
                    loc_output_format = output_format
                end

                return pandoc.RawInline(loc_output_format, bl)

            else
                qldebug("SPAN", "    ...custom-style: " .. custom_style)
                return el
            end    
        end

        return el
    end

}

return {filter}
