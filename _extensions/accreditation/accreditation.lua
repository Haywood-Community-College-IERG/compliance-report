-- From https://github.com/pandoc/lua-filters/blob/master/scholarly-metadata/scholarly-metadata.lua
local List = require 'pandoc.List'

local site_path = "_site"

local yaml_tagname = "accreditation"

local artifact_target = "_blank"
local artifact_page = false

local sources_style = "Sources"
local sources_header = "Sources"
local sources_path = "../documents"
local sources_path_sub = "" 
local sources_sorted = true

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

local link_standard_style = "Link to Standard"

local judgment_style = "Judgment"

local sources_html_hdr = '<ul type="1">'
local sources_html_ftr = '</ul>'
local sources_html_start = '<li>'
local sources_html_end = '</li>'

local sources_pdf_hdr = '<ol type="1">'
local sources_pdf_ftr = '</ol>'
local sources_pdf_start = '<li>'
local sources_pdf_end = '</li>'

local li_start = ""
local li_end = ""
local li_hdr = ""
local li_ftr = ""
local raw_type = "html"

local sources_list = {}

local trace_options = { "link_to_artifact_style",
                        --"link_to_artifact_style:evidence_search",
                        "link_standard_style", 
                        -- "make_link",
                        "unitcode_style",
                        -- "link_standard_style:evidence_search"
                        -- "sources_block",
                        -- "judgment_style",
                        -- "sources_style",
                        -- "DIV",
                        "SPAN",
                        --"STR","PLAIN",
                        -- "HEADER",
                        -- "META",
                        -- "IZ",
                     }

function contains(tbl, str)
    for _, value in pairs(tbl) do
        if value == str then
        return true
        end
    end
    return false
end
                      
local function qldebug(opt, msg)
    if contains(trace_options, opt) then
        quarto.log.debug(yaml_tagname .. ": [" .. opt .. "]: " .. msg)
    end
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
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
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
    
function make_link(path, evidence, evidence_pg, evidence_txt)
    qldebug("make_link", "    ...path: " .. path)
    qldebug("make_link", "    ...evidence: " .. evidence)
    qldebug("make_link", "    ...evidence_pg: " .. evidence_pg)
    qldebug("make_link", "    ...evidence_txt: " .. evidence_txt)

    -- Create the link to the evidence file as markdown. This will replace the former text.
    if raw_type == "html" then 
        if artifact_target ~= "" then 
            target_str = " target=\"" .. artifact_target .. "\""

        else
            target_str = ""

        end

        --rtn_str = "<a href=\"" .. sources_path .. "/" .. sources_path_sub .. "/" .. evidence .. evidence_pg .. "\" " .. target_str .. " >" .. evidence_txt .. "</a>"
        rtn_str = "<a href=\"" .. path .. evidence .. evidence_pg .. "\" " .. target_str .. " >" .. evidence_txt .. "</a>"

    elseif raw_type == "pdf" then
        rtn_str = "[" .. evidence_txt .. "](" .. path .. evidence .. evidence_pg .. ")"

    else 
        rtn_str = "[" .. evidence_txt .. "](" .. path .. evidence .. evidence_pg .. ")"

    end

    return rtn_str
    
end

function link_to_artifact(el, artifact_type)
    qldebug("link_to_artifact_style", "Check Span: ")
    qldebug("link_to_artifact_style", "    ...content: " .. dump(el.content))
    qldebug("link_to_artifact_style", "    ...attributes: " .. dump(el.attr))
    -- qldebug("link_to_artifact_style", "    ...custom-style: " .. pandoc.utils.stringify(el_attr["custom-style"]))

    extension = ".pdf"

    if artifact_type == "artifact" then
        evidence_txt = pandoc.utils.stringify(el.content)
        evidence = evidence_txt .. extension
    elseif artifact_type == "assessment" then
        evidence_txt = pandoc.utils.stringify(el.content)
        evidence = _G.unit_code .. link_to_artifact_assessment_sep .. evidence_txt .. link_to_artifact_assessment_suffix .. extension
    elseif artifact_type == "review" then
        evidence_txt = pandoc.utils.stringify(el.content)
        evidence = _G.unit_code .. link_to_artifact_review_sep .. evidence_txt .. link_to_artifact_review_suffix .. extension
    else
        qldebug("link_to_artifact_style", "ERROR: Unknown artifact type (" .. artifact_type .. ")")
        return el
    end
    
    evidence_pg = ""

    -- If the evidence has a page number, and artifact_page is true, 
    --     then construct the page number link
    pat = " - Page "
    idx = string.find(evidence,pat,1,true)
    if idx ~= nil then
        if artifact_page then
            evidence_pg = "#page=" .. string.sub(evidence,idx + string.len(pat))
        end

        -- Remove the page number from the evidence name
        evidence = string.sub(evidence, 1, idx - 1)

    elseif artifact_page then
        --  evidence_pg = "#page=1"
        evidence_pg = ""

    end

    qldebug("link_to_artifact_style", "    ...evidence: " .. evidence .. "  -  " .. evidence_pg)

    qldebug("link_to_artifact_style", "    ...dir_str: " .. quarto.project.offset .. "    -    " .. quarto.project.directory .. "    -    " .. quarto.doc.input_file) -- sources_path .. "/" .. sources_path_sub
    dir_str = pandoc.path.make_relative(pandoc.utils.stringify(sources_path), quarto.doc.input_file) .. "/" .. sources_path_sub
    qldebug("link_to_artifact_style", "    ...dir_str: " .. dir_str)

    -- Check for existence of evidence file in the document directory.
    -- All artifacts must be PDFs.
    files = pandoc.system.list_directory(dir_str)
    local fn = nil
    for _, file in ipairs(files) do 
        qldebug("link_to_artifact_style:evidence_search", "    ...dir: " .. file)
        if pandoc.utils.stringify(evidence) == pandoc.utils.stringify(file) then 
            fn = file 
            qldebug("link_to_artifact_style:evidence_search", "    ...dir(fn): " .. evidence)

        else
            qldebug("link_to_artifact_style:evidence_search", "    ...Not it - file: " .. file)

        end
    end
    if fn == nil then
        qldebug("link_to_artifact_style", "ERROR: Evidence file not found (" .. evidence .. ")")
    end

    rtn_str = make_link(sources_path .. "/" .. sources_path_sub .. "/", evidence, evidence_pg, evidence_txt)
    qldebug("link_to_artifact_style", "    ...custom-style: " .. rtn_str)

    -- Build up the list of sources. These will be managed below under the Sources Block
    if sources_sorted then
        local disp = nil
        if #sources_list == 0 then
            table.insert(sources_list, rtn_str)
            qldebug("link_to_artifact_style", "    ...first table insert: " .. rtn_str)
            disp = 1

        else
            for i = 1, #sources_list do
                if sources_list[i] == rtn_str then
                    qldebug("link_to_artifact_style", "    ...source already exists(" .. i .. "): " .. rtn_str)
                    disp = i
                    break

                elseif sources_list[i] >= rtn_str then
                    qldebug("link_to_artifact_style", "    ...insert source(" .. i .. "): " .. rtn_str)
                    table.insert(sources_list, i, rtn_str)
                    disp = i
                    break

                else
                    qldebug("link_to_artifact_style", "    ...CUR < EXIST(" .. i .. "): " .. rtn_str)

                end

            end

        end

        if disp == nil then
            qldebug("link_to_artifact_style", "    ...append source: " .. rtn_str)
            table.insert(sources_list, rtn_str)
            disp = #sources_list

        end

    else
        qldebug("link_to_artifact_style", "    ...append source: " .. rtn_str)
        table.insert(sources_list, rtn_str)

    end
    
    qldebug("link_to_artifact_style", "sources_list(" .. #sources_list .. "): " .. dump(sources_list))

    -- Now return the new link
    return pandoc.Span(pandoc.RawInline(raw_type,rtn_str))
    --return pandoc.Span(rtn_str)
end

function link_to_standard(el)
    local loc_standards_path = standards_path:gsub("\\","/")

    evidence_txt_orig = pandoc.utils.stringify(el.content)

    -- If quarto.doc.input_file contains standards_path, then set loc_standards_path to ""
    -- Convert the path to contain only /. 
    qpd = quarto.project.directory:gsub("\\","/")
    qldebug("link_standard_style", "    ...quarto.project.directory: " .. qpd )
    qdi = pandoc.path.directory(quarto.doc.input_file:gsub("\\","/"))
    qldebug("link_standard_style", "    ...quarto.doc.input_file: " .. qdi ) 
    if string.find(qdi, loc_standards_path, 1, true) then
        loc_standards_path = ""
    end
    -- Now add a trailing / if loc_standards_path is not empty
    if loc_standards_path ~= "" then
        loc_standards_path = loc_standards_path .. "/"
    end
    
    qldebug("link_standard_style", "    ...loc_standards_path: [" .. loc_standards_path .."]" )

    qldebug("link_standard_style", "    ...evidence_txt_orig: [" .. evidence_txt_orig .."]" )

    -- Insert leading zeros for the standard number when needed
    evidence_txt = insert_zero(evidence_txt_orig)
    evidence = evidence_txt

    pat = " - Section: "
    idx = string.find(evidence_txt,pat,1,true)
    if idx ~= nil then
        -- Sections are lowercase and use dashes for spaces in Quarto with no leading and trailing blanks
        evidence_pg = "#" .. string.lower(string.sub(evidence,idx + string.len(pat)))
        evidence_pg = string.gsub(evidence_pg:match("^%s*(.-)%s*$"), " ", "-")

        evidence = string.sub(evidence_txt, 1, idx - 1)
    else
        evidence_pg = ""
    end
    qldebug("link_standard_style", "    ...evidence_txt: " .. evidence .. " - " .. evidence_pg .. "  -  " .. evidence_txt)

    -- Check for existence of referenced standards file in the loc_standards_path directory.
    files = pandoc.system.list_directory(quarto.project.directory .. "/" .. standards_path)
    local fn = nil

    qldebug("link_standard_style", "    ...Looking for standard file: [" .. evidence .. ".qmd]  -  [" .. evidence .. standards_core_suffix .. ".qmd]")

    for _, file in ipairs(files) do 
        qldebug("link_standard_style:evidence_search", "    ...file: [" .. file .. "]")
        if (evidence .. ".qmd" == file) or (evidence .. standards_core_suffix .. ".qmd" == file) then 
            fn = file 
            qldebug("link_standard_style:evidence_search", "    ...fn: [" .. fn .. "]")
            break

        else
            qldebug("link_standard_style:evidence_search", "    ...Not it - file: [" .. file .. "]")

        end

    end

    if fn == nil then
        quarto.log.error("ERROR: Standard file not found (" .. evidence .. ")")
    else
        evidence = fn
        -- remove .qmd suffix
        evidence = string.sub(evidence, 1, #evidence - 4)
        qldebug("link_standard_style", "    ...Found evidence file [" .. evidence .. "]")

    end

    evidence = evidence .. ".html"

    rtn_str = make_link(loc_standards_path, evidence, evidence_pg, evidence_txt)
    qldebug("link_standard_style", "    ...rtn_str: " .. rtn_str)
    return pandoc.RawInline(raw_type, rtn_str)

end

local filter = {
    traverse = 'topdown',

    Meta = function(m)
        if quarto.doc.is_format("html") then
            li_start = sources_html_start
            li_end = sources_html_end
            li_hdr = sources_html_hdr
            li_ftr = sources_html_ftr
            raw_type = "html"
        elseif quarto.doc.is_format("pdf") then
            li_start = sources_pdf_start
            li_end = sources_pdf_end
            li_hdr = sources_pdf_hdr
            li_ftr = sources_pdf_ftr
            raw_type = "pdf"
        else
            li_start = " 1. "
            li_end = "\n\n"
            li_hdr = ""
            li_ftr = ""
        end        

        -- qldebug("META", "Check Meta: " .. dump(m))
        local accreditation_meta = ensure_list(m[yaml_tagname]):map(to_named_object)

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

            end
        end

        if artifact_page then
            pandoc.system.make_directory(site_path .. "/" .. sources_path .. "/" .. sources_path_sub, true)
        end

        return m
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
                return pandoc.Span(pandoc.RawInline(raw_type,""))
        
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

                --- Handle LINKs to standards
            elseif custom_style == link_standard_style then
                qldebug("link_standard_style", "Link to Standards")
                return link_to_standard(el)

            --- Handle SOURCES Style
            elseif custom_style == sources_style then
                qldebug("sources_block", "Sources Block")

                qldebug("sources_block", "sources_list: " .. dump(sources_list))

                rtn_str = pandoc.utils.stringify(li_hdr)
                for i = 1, #sources_list do
                    qldebug("sources_block", "    ...source(" .. i .. "): " .. sources_list[i])
                    rtn_str = pandoc.utils.stringify(rtn_str .. li_start .. sources_list[i] .. li_end)
                end
                rtn_str = pandoc.utils.stringify(rtn_str .. li_ftr)

                return pandoc.Span(pandoc.RawInline(raw_type, rtn_str))

            end    
        end

        return el
    end

}

return {filter}
