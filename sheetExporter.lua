local json = dofile("_modules/JSON.lua")
local dkJson = dofile("_modules/dkjson.lua")


local spr = app.activeSprite
if not spr then return print('No active sprite') end

local path,title = spr.filename:match("^(.+[/\\])(.-).([^.]*)$")
local msg = { "Do you want to export/overwrite the following files?" }

for i,tag in ipairs(spr.tags) do
  local fn = path .. title .. '-' .. tag.name
  table.insert(msg, '-' .. fn .. '.[png|json]')
end

-- uncomment to run the overrite alert
--if app.alert{ title="Export Sprite Sheets", text=msg,
--              buttons={ "&Yes", "&No" } } ~= 1 then
--  return
--end

function decodeFileIntoTable(path)

    local pathToJsonfile = io.open(path, "r")
    local contentAsString = pathToJsonfile:read("*all")  -- *all is one of the arguments of read()
    pathToJsonfile:close()
    local myTable = dkJson.decode(contentAsString)
    return myTable
    
end

function exportFunc(scaleFactor, jsonWrite, sheetType)

    for i,tag in ipairs(spr.tags) do   -- is like python's enumerate
        local fn = path  .. title .. '_' .. tag.name 

        if jsonWrite then
            app.command.ExportSpriteSheet{
                ui = false,
                type = sheetType,
                textureFilename = fn .. '.png',
                dataFilename = fn .. '.json',
                dataFormat = SpriteSheetDataFormat.JSON_ARRAY,
                filenameFormat = "{tag}_{frame}.{extension}",
                tag = tag.name,
                listLayers = false,
                listTags = false,
                listSlices = false
            }
        else
            app.command.ExportSpriteSheet{
                ui = false,
                type = sheetType,
                textureFilename = fn .. '.png',
                filenameFormat = "{tag}_{frame}.{extension}",
                tag = tag.name,
                listLayers = false,
                listTags = false,
                listSlices = false
            }
        end
        

        -- ##########################################################################
        -- scale png sheets (open as Aseprite file, resize and close)
        -- ##########################################################################
        
        local sprite = app.open(fn .. '.png')
        sprite:resize(sprite.width * scaleFactor,sprite.height * scaleFactor)
        local resizeFileName = sprite.filename
        local resizeFileNamePath = path  .. resizeFileName 
        
        app.command.SaveFile(fn .. '.png')
        app.command.CloseFile(fn .. '.png')

        
        -- ##########################################################################
        -- scale json sheets (decode saved json and multiply the "frame" key values by the scale)
        -- ##########################################################################
        
        if jsonWrite then
            -- 1. get all the values of the key "frame". Those are dicts containing "frame" key
            local dataTable = decodeFileIntoTable(fn .. '.json')
            local framesKeyTable = dataTable["frames"]
            
            -- 2. get all the values of the key "frame", which are x, y, w and h, multiply them by the scale
            -- (also multiply any other related keys)
            for k, v in pairs(framesKeyTable) do
                v["frame"]["x"] = v["frame"]["x"] * scaleFactor
                v["frame"]["y"] = v["frame"]["y"] * scaleFactor
                v["frame"]["w"] = v["frame"]["w"] * scaleFactor
                v["frame"]["h"] = v["frame"]["h"] * scaleFactor
                
                v["spriteSourceSize"]["x"] = v["spriteSourceSize"]["x"] * scaleFactor
                v["spriteSourceSize"]["y"] = v["spriteSourceSize"]["y"] * scaleFactor
                v["spriteSourceSize"]["w"] = v["spriteSourceSize"]["w"] * scaleFactor
                v["spriteSourceSize"]["h"] = v["spriteSourceSize"]["h"] * scaleFactor
                
                v["sourceSize"]["w"] = v["sourceSize"]["w"] * scaleFactor
                v["sourceSize"]["h"] = v["sourceSize"]["h"] * scaleFactor

                            
            end
        
            -- 4. save the json with those updated values
            local json_as_string = json.encode_pretty(json, dataTable)
            
            local myFilePath= fn .. '.json'
            local newFile = io.open(myFilePath, "w")  -- "w" for writing mode
            newFile.write(newFile, json_as_string)
            newFile.close(newFile)
        end
      
    end
    
end



-- UI

local dlg = Dialog{ title="Scalar sheet exporter" }
local sheetTypeValue = SpriteSheetType.HORIZONTAL

dlg:combobox{
    id="sheetType",
    label="Sheet Type: ",
    option="Horizontal Strip",
    options={"Horizontal Strip", "Vertical Strip", "By Rows", "By Columns", "Packed"},
    onchange=function ()
        if dlg.data.sheetType == "Horizontal Strip" then
            sheetTypeValue = SpriteSheetType.HORIZONTAL
        elseif dlg.data.sheetType == "Vertical Strip" then
            sheetTypeValue = SpriteSheetType.VERTICAL
        elseif dlg.data.sheetType == "By Rows" then
            sheetTypeValue = SpriteSheetType.ROWS
        elseif dlg.data.sheetType == "By Columns" then
            sheetTypeValue = SpriteSheetType.COLUMNS
        elseif dlg.data.sheetType == "Packed" then
            sheetTypeValue = SpriteSheetType.PACKED
        end
    end
}

dlg:number {
    id="scaleId",
    label="Scale: ",
    text=string.format("%.1f", 1),
    decimals=integer
}

dlg:check {
    id="jsonWrite",
    label="Save JSON: "
}

dlg:button {
    id="myButtonId",
    text="Save sheets",
    onclick=function()
        local dlgData = dlg.data
        exportFunc(dlgData.scaleId, dlgData.jsonWrite, sheetTypeValue)
    end
}

dlg:show()
