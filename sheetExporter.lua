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


function exportFunc(scaleFactor, sheetType, cellCount, cellSize, imageCheck, imagePath, jsonCheck, jsonPath)
    if not imagePath or imagePath == title then
        imagePath = path .. title
    end

    if not jsonPath or jsonPath == title then
        jsonPath = path .. title
    end

    for i,tag in ipairs(spr.tags) do   -- is like python's enumerate
        local imageFileName = nil
        local jsonFileName = nil

        if imageCheck then
            imageFileName = imagePath .. '_' .. tag.name .. '.png'
        end

        if jsonCheck then
            jsonFileName = jsonPath .. '_' .. tag.name  .. '.json'
        end

        app.command.ExportSpriteSheet{
            ui = false,
            type = sheetType,
            rows = cellCount[0],
            columns = cellCount[1],
            width = cellSize[0],
            height = cellSize[1],
            textureFilename = imageFileName,
            dataFilename = jsonFileName,
            dataFormat = SpriteSheetDataFormat.JSON_ARRAY,
            filenameFormat = "{tag}_{frame}.{extension}",
            tag = tag.name,
            listLayers = false,
            listTags = false,
            listSlices = false
        }
        
        -- ##########################################################################
        -- scale png sheets (open as Aseprite file, resize and close)
        -- ##########################################################################
        
        if imageCheck then
            local sprite = app.open(imageFileName)
            sprite:resize(sprite.width * scaleFactor,sprite.height * scaleFactor)
            local resizeFileName = sprite.filename
            local resizeFileNamePath = path  .. resizeFileName 
            
            app.command.SaveFile(imageFileName)
            app.command.CloseFile(imageFileName)
        end

        -- ##########################################################################
        -- scale json sheets (decode saved json and multiply the "frame" key values by the scale)
        -- ##########################################################################
        
        if jsonCheck then
            -- 1. get all the values of the key "frame". Those are dicts containing "frame" key
            local dataTable = decodeFileIntoTable(jsonFileName)
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
            
            local myFilePath= jsonFileName
            local newFile = io.open(myFilePath, "w")  -- "w" for writing mode
            newFile.write(newFile, json_as_string)
            newFile.close(newFile)
        end
      
    end
    
end

-- UI

local dlg = Dialog{ title="Scalar sheet exporter" }
local sheetTypeValue = SpriteSheetType.HORIZONTAL

dlg:tab {id = "tabLayout", text = "Layout"}

dlg:combobox{
    id="sheetType",
    label="Sheet Type: ",
    option="Horizontal Strip",
    options={"Horizontal Strip", "Vertical Strip", "By Rows", "By Columns", "Packed"},
    onchange=function ()
        if dlg.data.sheetType == "Horizontal Strip" then
            sheetTypeValue = SpriteSheetType.HORIZONTAL
            dlg:modify{id="constraints", options={"None"}}
        elseif dlg.data.sheetType == "Vertical Strip" then
            sheetTypeValue = SpriteSheetType.VERTICAL
            dlg:modify{id="constraints", options={"None"}}
        elseif dlg.data.sheetType == "By Rows" then
            sheetTypeValue = SpriteSheetType.ROWS
            dlg:modify{id="constraints", options={"None", "Fixed # of Columns", "Fixed Width"}}
        elseif dlg.data.sheetType == "By Columns" then
            sheetTypeValue = SpriteSheetType.COLUMNS
            dlg:modify{id="constraints", options={"None", "Fixed # of Rows", "Fixed Height"}}
        elseif dlg.data.sheetType == "Packed" then
            sheetTypeValue = SpriteSheetType.PACKED
            dlg:modify{id="constraints", options={"None", "Fixed Width", "Fixed Height", "Fixed Size"}}
        end
    end
}

dlg:combobox{
    id="constraints",
    label="Constraints: ",
    hexpand=true,
    option="None",
    options={"None"},
    onchange=function ()
        dlg:modify{id="sizeX", visible=false}
        dlg:modify{id="sizeY", visible=false}
        dlg:modify{id="rowCount", visible=false}
        dlg:modify{id="columnCount", visible=false}

        if dlg.data.constraints == "None" then
            return
        end

        if dlg.data.constraints == "Fixed # of Rows" then
            dlg:modify{id="rowCount", visible=true}
        elseif dlg.data.constraints == "Fixed # of Columns" then
            dlg:modify{id="columnCount", visible=true}
        elseif dlg.data.constraints == "Fixed Width" then
            dlg:modify{id="sizeX", visible=true}
        elseif dlg.data.constraints == "Fixed Height" then
            dlg:modify{id="sizeY", visible=true}
        elseif dlg.data.constraints == "Fixed Size" then
            dlg:modify{id="sizeX", visible=true}
            dlg:modify{id="sizeY", visible=true}
        end
    end
}
dlg:number {
    id="sizeX",
    decimals=integer,
    visible=false
}
dlg:number {
    id="sizeY",
    decimals=integer,
    visible=false
}
dlg:number {
    id="rowCount",
    decimals=integer,
    visible=false
}
dlg:number {
    id="columnCount",
    decimals=integer,
    visible=false
}

dlg:tab {id = "tabSprite", text = "Sprite"}

dlg:number {
    id="scaleId",
    label="Scale: ",
    text=string.format("%.1f", 1),
    decimals=integer
}

dlg:tab {id = "tabOutput", text = "Output"}

dlg:newrow()

dlg:check {
    id="outputCheck",
    label="Output File:",
    onclick=function ()
        dlg:modify{id="outputFilePath", visible=(dlg.data.outputCheck) }
        dlg:modify{id="exportButton", enabled= dlg.data.jsonCheck or dlg.data.outputCheck }
    end
}

dlg:file {
    id="outputFilePath",
    filetypes={},
    filename = title,
    visible=false
}

dlg:newrow()

dlg:check {
    id="jsonCheck",
    label="JSON Data: ",
    onclick=function ()
        dlg:modify{id="jsonFilePath", visible=dlg.data.jsonCheck }
        dlg:modify{id="exportButton", enabled= dlg.data.jsonCheck or dlg.data.outputCheck }
    end
}

dlg:file {
    id="jsonFilePath",
    filetypes={},
    filename = title,
    visible=false
}

dlg:endtabs{
    selected = "tabLayout",
    align = integer
}

dlg:button {
    id="exportButton",
    text="Export Sheets",
    enabled=false,
    onclick=function()
        local dlgData = dlg.data
        local cellCount = {}
        local cellSize = {}

        if dlgData.constraints == "Fixed # of Rows" then
            cellCount[0] = dlgData.rowCount
        elseif dlgData.constraints == "Fixed # of Columns" then
            cellCount[1] = dlgData.columnCount
        elseif dlgData.constraints == "Fixed Width" then
            cellSize[0] = dlgData.sizeX
        elseif dlgData.constraints == "Fixed Height" then
            cellSize[1] = dlgData.sizeY
        elseif dlgData.constraints == "Fixed Size" then
            cellSize[0] = dlgData.sizeX
            cellSize[1] = dlgData.sizeY
        end

        exportFunc(dlgData.scaleId, sheetTypeValue, cellCount, cellSize, dlgData.outputCheck, dlgData.outputFilePath, dlgData.jsonCheck, dlgData.jsonFilePath)
    end
}

dlg:button {
    text="Cancel",
    onclick=function ()
        dlg:close()
    end
}

dlg:show()
