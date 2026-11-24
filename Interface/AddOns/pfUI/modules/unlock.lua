pfUI:RegisterModule("unlock", "vanilla:tbc", function ()
  local rawborder, default_border = GetBorderSize()

  -- grouped frames
  local clusters = {
    -- Name            Shift  Ctrl
    { "pfCombo",          5       },
    { "pfRaid",           40,   5 },
    { "pfGroup",          4       },
    { "pfLootRollFrame",  4       },
  }

  -- BOTTOM = bottom edge + horizontal mid (X from the vertical mid-line).
  local anchors = {
    "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT",
    "BOTTOM", "BOTTOMLEFT", "LEFT", "CENTER"
  }

  local function NativePoint(anchor)
    return (pfUI.api and pfUI.api.NativePoint and pfUI.api.NativePoint(anchor)) or anchor or "TOPLEFT"
  end

  -- Unlock works in grid cells (screen width / 128). SetPoint still needs pixels.
  local function SnapCoord(v)
    if type(v) ~= "number" then return v end
    return math.floor(v + 0.5)
  end

  local function SetLogicalPoint(frame, anchor, x, y)
    if anchor == "CENTERBOTTOM" then anchor = "BOTTOM" end
    frame.pfAnchor = anchor
    local point = NativePoint(anchor)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, GridToPixel(x), GridToPixel(y))
  end

  -- x/y are grid cells (float OK). Within half a cell of a green mid-line,
  -- snap that axis to 0; then both axes to integers. Threshold is <0.5 so
  -- intentional ±1 (e.g. Group1 on LEFT with Y=-1) is not eaten.
  local function SnapSeat(anchor, x, y)
    if anchor == "TOP" or anchor == "BOTTOM" or anchor == "CENTER" then
      if math.abs(x) < 0.5 then x = 0 end
    end
    if anchor == "LEFT" or anchor == "RIGHT" or anchor == "CENTER" then
      if math.abs(y) < 0.5 then y = 0 end
    end
    return SnapCoord(x), SnapCoord(y)
  end

  -- ConvertFrameAnchor returns pixels; prefer float cells into SnapSeat so
  -- the half-cell mid-line test runs before integer rounding.
  local function CellsFromPixel(px)
    local step = GridStep()
    if not step or step <= 0 then return 0 end
    return (tonumber(px) or 0) / step
  end

  local function DockAxisLabels(anchor)
    anchor = anchor or "TOPLEFT"
    local xmid = (anchor == "TOP" or anchor == "BOTTOM" or anchor == "CENTER")
    local ymid = (anchor == "LEFT" or anchor == "RIGHT" or anchor == "CENTER")
    return xmid and T["X (mid)"] or "X:", ymid and T["Y (mid)"] or "Y:"
  end

  local function LogicalAnchor(frame)
    if not frame then return "TOPLEFT" end
    local anchor = frame.pfAnchor
    if not anchor then
      local name = frame.GetName and frame:GetName()
      local cfg = name and pfUI_config.position and pfUI_config.position[name]
      anchor = (cfg and cfg.anchor) or "TOPLEFT"
    end
    if anchor == "CENTERBOTTOM" then return "BOTTOM" end
    return anchor
  end

  -- Live logical offsets in grid cells (not raw GetPoint: StartMoving pins
  -- TOPLEFT against the screen root).
  local function LogicalOffsets(frame)
    local anchor = LogicalAnchor(frame)
    local a, x, y = ConvertFrameAnchor(frame, anchor)
    if not x or not y then return anchor, 0, 0 end
    return a, PixelToGrid(x), PixelToGrid(y)
  end

  -- Forward decls (called before their local definitions).
  local SavePosition, UpdateDockValues, ApplyUnlockSize

  local function FrameSizeCells(frame)
    if not frame then return 1, 1 end
    local w = PixelToGrid(frame:GetWidth() or 0)
    local h = PixelToGrid(frame:GetHeight() or 0)
    if w < 1 then w = 1 end
    if h < 1 then h = 1 end
    return w, h
  end

  local actionbar_ids = {
    Main = 1, Paging = 2, Right = 3, Vertical = 4, Left = 5, Top = 6,
    StanceBar1 = 7, StanceBar2 = 8, StanceBar3 = 9, StanceBar4 = 10,
    Stances = 11, Pet = 12,
  }

  local function ActionBarId(name)
    if not name or strsub(name, 1, 11) ~= "pfActionBar" then return nil end
    return actionbar_ids[strsub(name, 12)]
  end

  -- Persist size: SetWidth/SetHeight + module config where known. Never SetScale.
  -- snap=true → whole cells (drag release); false keeps dock decimals.
  ApplyUnlockSize = function(frame, wCells, hCells, snap)
    if not frame then return end
    wCells = tonumber(wCells)
    hCells = tonumber(hCells)
    if not wCells or not hCells then return end
    if snap then
      wCells = SnapCoord(wCells)
      hCells = SnapCoord(hCells)
    end
    if wCells < 1 then wCells = 1 end
    if hCells < 1 then hCells = 1 end

    local name = frame:GetName()
    local pxW, pxH = GridToPixel(wCells), GridToPixel(hCells)
    local bar = ActionBarId(name)

    if bar and pfUI.bars and C.bars and C.bars["bar"..bar] then
      -- Keep the unlock box exact (W/H stick). Fit icons inside it.
      local bcfg = C.bars["bar"..bar]
      local buttons = tonumber(bcfg.buttons) or 12
      if bar == 11 then
        buttons = (GetNumShapeshiftForms and GetNumShapeshiftForms()) or buttons
      elseif bar == 12 then
        buttons = NUM_PET_ACTION_SLOTS or 10
      end
      if buttons < 1 then buttons = 1 end
      local spacing = tonumber(bcfg.spacing) or 3
      local rawb, border = GetBorderSize("actionbars")
      border = border or rawb or 3
      local formfactor, icon = BarFitToSize(buttons, pxW, pxH, border, spacing)
      bcfg.formfactor = formfactor
      bcfg.icon_size = tostring(icon)
      SaveUnlockSize(frame, wCells, hCells)
      if pfUI.bars.UpdateConfig then pfUI.bars:UpdateConfig() end
      -- UpdateConfig rebuilds from icon_size; re-apply the outer box.
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
    elseif frame.config and frame.UpdateConfig and frame.config.width then
      -- Unitframes: outer box is unlock W/H. Scale HP + power together so a
      -- tall pheight (e.g. Adapta player = 2) does not floor the whole frame.
      local step = GridStep()
      local function FineCells(px)
        if step <= 0 then return 1 end
        local n = px / step
        return math.floor(n * 100 + 0.5) / 100
      end

      local rawb, uf_border = GetBorderSize("unitframes")
      uf_border = uf_border or rawb or 3
      local pspace = tonumber(frame.config.pspace) or 0
      local spacing = pspace * GetPerfectPixel()
      local cfgW = tonumber(frame.config.width) or 1
      local cfgH = tonumber(frame.config.height) or 1
      local cfgP = tonumber(frame.config.pheight) or 0

      local chromeW = (frame:GetWidth() or 0) - ConfigSize(cfgW)
      if chromeW < 0 then chromeW = 0 end
      local newCfgW = FineCells(pxW - chromeW)
      -- 0.5 cells (~6px) is too narrow for name/HP text (party targets).
      if newCfgW < 4 then newCfgW = 4 end

      -- Match pfUI.uf:UpdateFrameSize: real = hp + spacing + power + 2*border,
      -- unless negative pspace collapses to hp-only.
      local newCfgH, newCfgP = cfgH, cfgP
      local psize = ConfigSize(frame.config.pheight)
      if spacing ~= math.abs(spacing) and math.abs(spacing) > math.abs(psize) then
        newCfgH = FineCells(pxH)
      else
        local budget = pxH - spacing - 2 * uf_border
        if budget < step * 0.5 then budget = step * 0.5 end
        if cfgP < 0 then
          newCfgH = FineCells(budget)
        else
          local sum = cfgH + math.max(cfgP, 0)
          if sum < 0.01 then sum = 0.01 end
          local total = FineCells(budget)
          if total < 0.5 then total = 0.5 end
          newCfgH = math.floor(total * (cfgH / sum) * 100 + 0.5) / 100
          newCfgP = math.floor(total * (math.max(cfgP, 0) / sum) * 100 + 0.5) / 100
          if newCfgH < 0.25 then newCfgH = 0.25 end
          if cfgP > 0 and newCfgP < 0.25 then newCfgP = 0.25 end
          frame.config.pheight = tostring(newCfgP)
        end
      end
      if newCfgH < 0.25 then newCfgH = 0.25 end

      frame.config.width = tostring(newCfgW)
      frame.config.height = tostring(newCfgH)
      frame:UpdateConfig()
      -- Keep the unlock box exact (same idea as action bars).
      SaveUnlockSize(frame, wCells, hCells)
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
    elseif name == "pfChatLeft" then
      C.chat.left.width = tostring(wCells)
      C.chat.left.height = tostring(hCells)
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
      if pfUI.panel and pfUI.panel.left then
        pfUI.panel.left:SetWidth(pxW - 4)
      end
      SaveUnlockSize(frame, wCells, hCells)
    elseif name == "pfChatRight" then
      C.chat.right.width = tostring(wCells)
      C.chat.right.height = tostring(hCells)
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
      if pfUI.panel and pfUI.panel.right then
        pfUI.panel.right:SetWidth(pxW - 4)
      end
      SaveUnlockSize(frame, wCells, hCells)
    elseif name == "pfPlayerCastbar" and C.castbar and C.castbar.player then
      C.castbar.player.width = tostring(wCells)
      C.castbar.player.height = tostring(hCells)
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
      SaveUnlockSize(frame, wCells, hCells)
    elseif name == "pfTargetCastbar" and C.castbar and C.castbar.target then
      C.castbar.target.width = tostring(wCells)
      C.castbar.target.height = tostring(hCells)
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
      SaveUnlockSize(frame, wCells, hCells)
    elseif name == "pfFocusCastbar" and C.castbar and C.castbar.focus then
      C.castbar.focus.width = tostring(wCells)
      C.castbar.focus.height = tostring(hCells)
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
      SaveUnlockSize(frame, wCells, hCells)
    elseif name == "pfMinimap" and C.appearance and C.appearance.minimap then
      local side = wCells < hCells and wCells or hCells
      C.appearance.minimap.size = tostring(side)
      if pfUI.minimap and pfUI.minimap.UpdateConfig then
        pfUI.minimap:UpdateConfig()
      else
        frame:SetWidth(GridToPixel(side))
        frame:SetHeight(GridToPixel(side))
      end
      SaveUnlockSize(frame, side, side)
    elseif name == "pfExperienceBar" and C.panel and C.panel.xp then
      C.panel.xp.xp_width = tostring(wCells)
      C.panel.xp.xp_height = tostring(hCells)
      if pfUI.xpbar and pfUI.xpbar.UpdateConfig then pfUI.xpbar:UpdateConfig() end
      SaveUnlockSize(frame, wCells, hCells)
    elseif name == "pfReputationBar" and C.panel and C.panel.xp then
      C.panel.xp.rep_width = tostring(wCells)
      C.panel.xp.rep_height = tostring(hCells)
      if pfUI.xpbar and pfUI.xpbar.UpdateConfig then pfUI.xpbar:UpdateConfig() end
      SaveUnlockSize(frame, wCells, hCells)
    elseif name == "pfPlayerBuffBar" and C.buffbar and C.buffbar.pbuff then
      C.buffbar.pbuff.width = tostring(wCells)
      C.buffbar.pbuff.height = tostring(hCells)
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
      SaveUnlockSize(frame, wCells, hCells)
    elseif name == "pfPlayerDebuffBar" and C.buffbar and C.buffbar.pdebuff then
      C.buffbar.pdebuff.width = tostring(wCells)
      C.buffbar.pdebuff.height = tostring(hCells)
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
      SaveUnlockSize(frame, wCells, hCells)
    elseif name == "pfTargetDebuffBar" and C.buffbar and C.buffbar.tdebuff then
      C.buffbar.tdebuff.width = tostring(wCells)
      C.buffbar.tdebuff.height = tostring(hCells)
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
      SaveUnlockSize(frame, wCells, hCells)
    else
      frame:SetWidth(pxW)
      frame:SetHeight(pxH)
      SaveUnlockSize(frame, wCells, hCells)
    end

    -- Keep the seat after a size change (anchor stays put).
    local anchor, xpos, ypos = LogicalOffsets(frame)
    SetLogicalPoint(frame, anchor, xpos, ypos)
    SavePosition(frame)
    if frame.OnMove then frame:OnMove() end
  end

  local function NudgeFrame(dx, dy)
    local frame = pfUI.unlock.dock.parent.frame
    local anchor, xpos, ypos = LogicalOffsets(frame)
    SetLogicalPoint(frame, anchor, xpos + dx, ypos + dy)
    SavePosition(frame)
    UpdateDockValues()
  end

  local spanframe = CreateFrame("Frame", "pfUnlockSelector", UIParent)
  spanframe:Hide()

  -- frame labels and their config section relation
  local frame_configs = {
    -- unitframes
    ["Player"]             = { T["Unit Frames"], T["Player"] },
    ["Target"]             = { T["Unit Frames"], T["Target"] },
    ["TargetTarget"]       = { T["Unit Frames"], T["Target-Target"] },
    ["Pet"]                = { T["Unit Frames"], T["Pet"] },
    ["PetTarget"]          = { T["Unit Frames"], T["Pet-Target"] },
    ["Focus"]              = { T["Unit Frames"], T["Focus"] },

    -- combopoints
    ["Combo%d"]       = { T["Unit Frames"], T["General"] },

    -- groupframes
    ["Raid%d"]        = { T["Group Frames"], T["Raid"] },
    ["Raid%d%d"]      = { T["Group Frames"], T["Raid"] },
    ["Group%d"]       = { T["Group Frames"], T["Group"] },
    ["Party%dTarget"] = { T["Group Frames"], T["Group-Target"] },
    ["PartyPet%d"]    = { T["Group Frames"], T["Group-Pet"] },

    -- chat
    ["ChatLeft"]      = { T["Chat"], nil },
    ["ChatRight"]     = { T["Chat"], nil },
    ["ChatInputBox"]  = { T["Chat"], nil },

    -- loot
    ["LootRollFrame%d"] = { T["Loot"], nil },

    -- panel
    ["PanelLeft"]        = { T["Panel"], T["General"] },
    ["PanelRight"]       = { T["Panel"], T["General"] },
    ["PanelMinimap"]     = { T["Panel"], T["General"] },
    ["PanelMicroButton"] = { T["Panel"], T["General"] },

    -- actionbar
    ["ActionBarMain"]        = { T["Actionbar"], T["Main Actionbar"]},
    ["ActionBarPaging"]      = { T["Actionbar"], T["Paging Actionbar"]},
    ["ActionBarRight"]       = { T["Actionbar"], T["Right Actionbar"]},
    ["ActionBarVertical"]    = { T["Actionbar"], T["Vertical Actionbar"]},
    ["ActionBarLeft"]        = { T["Actionbar"], T["Left Actionbar"]},
    ["ActionBarTop"]         = { T["Actionbar"], T["Top Actionbar"]},
    ["ActionBarStanceBar1"]  = { T["Actionbar"], T["Stance Bar 1"]},
    ["ActionBarStanceBar2"]  = { T["Actionbar"], T["Stance Bar 2"]},
    ["ActionBarStanceBar3"]  = { T["Actionbar"], T["Stance Bar 3"]},
    ["ActionBarStanceBar4"]  = { T["Actionbar"], T["Stance Bar 4"]},
    ["ActionBarStances"]     = { T["Actionbar"], T["Stance/Shapeshift Actionbar"]},
    ["ActionBarPet"]         = { T["Actionbar"], T["Pet Actionbar"]},

    -- castbar
    ["TargetCastbar"]  = { T["Castbar"], nil },
    ["PlayerCastbar"]  = { T["Castbar"], nil },
    ["FocusCastbar"]   = { T["Castbar"], nil },

    -- minimap
    ["Minimap"]        = { T["Minimap"], T["Minimap"] },
    ["UITracking"]     = { T["Minimap"], T["Minimap"] },

    -- buffs
    ["BuffFrame"]      = { T["Buffs"], T["Buff/Debuff Icons"] },
    ["DebuffFrame"]    = { T["Buffs"], T["Buff/Debuff Icons"] },

    -- buffbars
    ["PlayerBuffBar"]   = { T["Buffs"], T["Player Buff Bar"] },
    ["PlayerDebuffBar"] = { T["Buffs"], T["Player Debuff Bar"] },
    ["TargetDebuffBar"] = { T["Buffs"], T["Target Debuff Bar"] },
  }

  local function GetFrames()
    -- Return frames based on Ctrl and Shift state
    -- 'this'   [frame]       the base frame
    -- return   [list]        all frames that should be selected

    local frame = this.frame
    local frames = { frame }

    if IsShiftKeyDown() or IsControlKeyDown() then
      -- search and add clustered frames
      for id, cluster in pairs(clusters) do
        local len = strlen(cluster[1])
        if strsub(frame:GetName(),0,len) == cluster[1] then
          if IsShiftKeyDown() and cluster[2] then
            for i = 1, cluster[2] do
              if _G[cluster[1] .. i] ~= frame then
                table.insert(frames, _G[cluster[1] .. i])
              end
            end
          elseif IsControlKeyDown() and cluster[3] then
            local id = tonumber(strsub(frame:GetName(),len+1,len+2))

            local b = 1
            for i = cluster[3]+1, cluster[2], cluster[3] do
              b = ( id >= i ) and i or b
            end

            for i = b, b + cluster[3] - 1 do
              if _G[cluster[1] .. i] ~= frame then
                table.insert(frames, _G[cluster[1] .. i])
              end
            end
          end
        end
      end
    end

    return frames
  end

  SavePosition = function(frame)
    SaveMovable(frame)
    UpdateMovable(frame)
  end

  local function DrawGrid()
    local grid = CreateFrame("Frame", this:GetName() .. "Grid", pfUI.unlock)
    grid:SetAllPoints(this)

    local size = 1
    local line = {}

    local width = GetScreenWidth()
    local height = GetScreenHeight()

    local ratio = width / GetScreenHeight()
    local rheight = GetScreenHeight() * ratio

    local wStep = width / 128
    local hStep = rheight / 128

    -- vertical lines
    for i = 0, 128 do
      if i == 128 / 2 then
        line = grid:CreateTexture(nil, 'BORDER')
        line:SetTexture(.1, .5, .4)
      else
        line = grid:CreateTexture(nil, 'BACKGROUND')
        line:SetTexture(0, 0, 0, .5)
      end
      line:SetPoint("TOPLEFT", grid, "TOPLEFT", i*wStep - (size/2), 0)
      line:SetPoint('BOTTOMRIGHT', grid, 'BOTTOMLEFT', i*wStep + (size/2), 0)
    end

    -- horizontal lines
    for i = 1, floor(height/hStep) do
      if i == floor(height/hStep / 2) then
        line = grid:CreateTexture(nil, 'BORDER')
        line:SetTexture(.1, .5, .4)
      else
        line = grid:CreateTexture(nil, 'BACKGROUND')
        line:SetTexture(0, 0, 0)
      end

      line:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -(i*hStep) + (size/2))
      line:SetPoint('BOTTOMRIGHT', grid, 'TOPRIGHT', 0, -(i*hStep + size/2))
    end

    return grid
  end

  local function GetConfigTable(dlabel)
    local cat, conf = nil, nil
    for label, config in pairs(frame_configs) do
      if string.gsub(dlabel, label, "") == "" then
        cat, conf = config[1], config[2]
      end
    end

    return cat, conf
  end

  local function OpenConfigDialog(category, view)
    pfUI.gui:Show()

    if not pfUI.gui.frames[category] then return end
    pfUI.gui.frames[category]:Click()

    if not view or not pfUI.gui.frames[category][view] then return end
    pfUI.gui.frames[category][view]:Click()
  end

  UpdateDockValues = function()
    if not pfUI.unlock.dock:IsShown() then return end

    local dock = pfUI.unlock.dock
    local drag = dock.parent
    local frame = drag.frame

    -- update dock position
    SetAutoPoint(dock, drag, default_border*2+2)

    -- update dock entries
    dock.title:SetText(drag.label)

    -- Always show live size in grid cells.
    local ww, hh = FrameSizeCells(frame)
    dock.wcoord:SetText(ww)
    dock.hcoord:SetText(hh)

    if pfUI_config["position"] and pfUI_config["position"][drag.fname] and pfUI_config["position"][drag.fname]["xpos"] ~= nil then
      -- Show live logical offsets (grid cells) so the dock matches the seat
      -- after a StartMoving pin, not whatever GetPoint last wrote into config.
      local anchor, xpos, ypos = LogicalOffsets(frame)
      -- Seats snap to whole cells; show integers so float round-trips
      -- (0.99984) never appear in the dock.
      dock.xcoord:SetText(SnapCoord(xpos))
      dock.ycoord:SetText(SnapCoord(ypos))
      local xlab, ylab = DockAxisLabels(anchor)
      dock.xcoordcap:SetText(xlab)
      dock.ycoordcap:SetText(ylab)

      for id, k in pairs(anchors) do
        -- get human readable
        local value, text = strsplit(":", k)
        text = text or value

        if value == anchor then
          UIDropDownMenu_SetSelectedID(pfUI.unlock.dock.anchor, id, 0)
          UIDropDownMenu_SetText(text, pfUI.unlock.dock.anchor)
        end
      end

      dock.reset:SetText(T["Reset"])

      dock.up:Enable()
      dock.down:Enable()
      dock.left:Enable()
      dock.right:Enable()

      dock.up.texture:SetVertexColor(1,.8,0)
      dock.down.texture:SetVertexColor(1,.8,0)
      dock.left.texture:SetVertexColor(1,.8,0)
      dock.right.texture:SetVertexColor(1,.8,0)
    else
      dock.reset:SetText(T["Unlock"])
      dock.xcoord:SetText(T["N/A"])
      dock.ycoord:SetText(T["N/A"])
      dock.xcoordcap:SetText("X:")
      dock.ycoordcap:SetText("Y:")

      dock.up:Disable()
      dock.down:Disable()
      dock.left:Disable()
      dock.right:Disable()

      dock.up.texture:SetVertexColor(.4,.4,.4)
      dock.down.texture:SetVertexColor(.4,.4,.4)
      dock.left.texture:SetVertexColor(.4,.4,.4)
      dock.right.texture:SetVertexColor(.4,.4,.4)
    end

    -- update config button
    local cat, conf = GetConfigTable(drag.label)
    if cat then
      dock.config:Enable()
    else
      dock.config:Disable()
    end
  end

  local function SetDockToFrame(frame)
    if pfUI.unlock.dock.parent then
      -- reset previous border color
      CreateBackdrop(pfUI.unlock.dock.parent, nil, nil, .8)
    end

    -- add the new frame
    pfUI.unlock.dock.parent = frame

    if frame then
      pfUI.unlock.dock.parent.backdrop:SetBackdropBorderColor(.2,1,.8,1)
      pfUI.unlock.dock:Show()
      UpdateDockValues()
    else
      pfUI.unlock.dock:Hide()
    end
  end

  local function DraggerOnDragStart()
    local frame = this.frame

    pfUI.unlock.selection = GetFrames()

    -- Remember each seat's logical anchor before StartMoving rewrites it to
    -- TOPLEFT; drag-stop keeps that anchor so BOTTOM/CENTER X/Y stay in the
    -- coordinate system the user picked.
    for id, fr in pairs(pfUI.unlock.selection) do
      fr.dragLogical = LogicalAnchor(fr)
      fr:StartMoving()
      fr:StopMovingOrSizing()
      fr.drag.backdrop:SetBackdropBorderColor(.2,1,.8,1)
    end

    local anchor, _, _, xpos, ypos = frame:GetPoint()
    frame.oldPos = { xpos, ypos, anchor }
    frame:StartMoving()

    if frame.OnMove then frame:OnMove() end
  end

  local function DraggerOnDragStop()
    local frame = this.frame
    local name = this.fname

    frame:StopMovingOrSizing()

    -- calculate and move selection offsets (pixel space while dragging)
    local anchor, xpos, ypos = ConvertFrameAnchor(frame, frame.oldPos[3])
    local diffxpos = frame.oldPos[1] - xpos
    local diffypos = frame.oldPos[2] - ypos

    for id, fr in pairs(pfUI.unlock.selection) do
      fr:SetParent("UIParent")
      if fr:GetName() ~= name then
        local a, _, _, x, y = fr:GetPoint()
        fr:SetPoint(a or "TOPLEFT", x - diffxpos, y - diffypos)
      end
    end

    -- Keep the pre-drag logical anchor (BOTTOM / CENTER…). Fall back to
    -- smallest-offset pick only when none was stored. Snap in grid cells.
    for id, fr in pairs(pfUI.unlock.selection) do
      CreateBackdrop(fr.drag, nil, nil, .8)
      local keep = fr.dragLogical
      if not keep or keep == "" then
        keep = GetBestAnchor(fr) or "TOPLEFT"
      end
      if keep == "CENTERBOTTOM" then keep = "BOTTOM" end
      local a, x, y = ConvertFrameAnchor(fr, keep)
      x, y = SnapSeat(a, CellsFromPixel(x), CellsFromPixel(y))
      SetLogicalPoint(fr, a, x, y)
      SavePosition(fr)
      fr.dragLogical = nil
    end

    this.backdrop:SetBackdropBorderColor(1,1,1,1)
    UpdateDockValues()
  end

  local function DraggerOnClick()
    if arg1 == "RightButton" then
      -- add dockframe to the dragger to show advanced options
      if pfUI.unlock.dock.parent == this and pfUI.unlock.dock:IsShown() then
        SetDockToFrame(nil)
      else
        SetDockToFrame(this)
      end
      return
    elseif arg1 == "MiddleButton" then
      -- reset positions (and unlock size) of dragger and all connected frames
      pfUI.unlock.selection = GetFrames()
      for id, frame in pairs(pfUI.unlock.selection) do
        local name = frame:GetName()
        pfUI_config["position"][name] = nil
        frame.pfAnchor = nil
        if frame.config and frame.posdata then
          if frame.posdata.cfgWidth then frame.config.width = frame.posdata.cfgWidth end
          if frame.posdata.cfgHeight then frame.config.height = frame.posdata.cfgHeight end
          if frame.UpdateConfig then frame:UpdateConfig() end
        end
        local bar = ActionBarId(name)
        if bar and C.bars and C.bars["bar"..bar] and frame.posdata then
          if frame.posdata.icon_size then
            C.bars["bar"..bar].icon_size = frame.posdata.icon_size
          end
          if frame.posdata.formfactor then
            C.bars["bar"..bar].formfactor = frame.posdata.formfactor
          end
          if pfUI.bars and pfUI.bars.UpdateConfig then pfUI.bars:UpdateConfig() end
        end
        UpdateMovable(frame)

        if frame.OnMove then frame:OnMove() end
      end
      UpdateDockValues()
    end
  end

  local function DraggerOnEnter()
    if pfUI.unlock.dock.parent ~= this then
      this.backdrop:SetBackdropBorderColor(1,1,1,1)
    end
  end

  local function DraggerOnLeave()
    if pfUI.unlock.dock.parent ~= this then
      CreateBackdrop(this, nil, nil, .8)
    end
  end

  local function CreateDragger(f)
    local fname = f:GetName()
    local label = string.sub(fname, 1, 2) == "pf" and strsub(fname,3) or fname

    local d = CreateFrame("Button", fname .. "Drag", f)
    d:RegisterForClicks("MiddleButtonUp", "RightButtonUp")
    d:RegisterForDrag("LeftButton")
    d:SetAllPoints(f)
    d:SetAlpha(1)

    d:SetFrameLevel(128)

    d.text = d:CreateFontString("Status", "LOW", "GameFontNormal")
    d.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    d.text:ClearAllPoints()
    d.text:SetAllPoints(d)
    d.text:SetPoint("CENTER", 0, 0)
    d.text:SetFontObject(GameFontWhite)

    d.frame = f
    d.fname = fname
    d.label = label

    if d:GetHeight() > (2 * d:GetWidth()) then
      label = strvertical(label)
    end

    d.text:SetText(label)

    d:SetScript("OnDragStart", DraggerOnDragStart)
    d:SetScript("OnDragStop", DraggerOnDragStop)
    d:SetScript("OnClick", DraggerOnClick)
    d:SetScript("OnEnter", DraggerOnEnter)
    d:SetScript("OnLeave", DraggerOnLeave)

    CreateBackdrop(d, nil, nil, .8)

    -- Four corner grips (custom drag; 1.12 has no reliable StartSizing).
    -- Dragging a corner keeps the opposite corner fixed in screen space.
    local function RestoreDragLabel(frame)
      if not (frame.drag and frame.drag.text) then return end
      local lab = frame.drag.label
      if frame.drag:GetHeight() > (2 * frame.drag:GetWidth()) then
        lab = strvertical(lab)
      end
      frame.drag.text:SetText(lab)
    end

    -- Sit fully outside the box so small frames stay grabbable.
    local corners = {
      { "TOPLEFT", "BOTTOMRIGHT", "TOPLEFT" },
      { "TOPRIGHT", "BOTTOMLEFT", "TOPRIGHT" },
      { "BOTTOMLEFT", "TOPRIGHT", "BOTTOMLEFT" },
      { "BOTTOMRIGHT", "TOPLEFT", "BOTTOMRIGHT" },
    }
    d.resizes = {}
    for i = 1, 4 do
      local corner, gripPoint, hostPoint = corners[i][1], corners[i][2], corners[i][3]
      local grip = CreateFrame("Button", fname .. "Resize" .. corner, d)
      grip:SetWidth(12)
      grip:SetHeight(12)
      grip:SetPoint(gripPoint, d, hostPoint, 0, 0)
      grip:SetFrameLevel(d:GetFrameLevel() + 2)
      grip:RegisterForDrag("LeftButton")
      grip.texture = grip:CreateTexture(nil, "ARTWORK")
      grip.texture:SetTexture(.2, 1, .8, .9)
      grip.texture:SetAllPoints(grip)
      grip.frame = f
      grip.corner = corner
      grip:SetScript("OnEnter", function()
        this.texture:SetTexture(.4, 1, .9, 1)
      end)
      grip:SetScript("OnLeave", function()
        if not this.resizing then
          this.texture:SetTexture(.2, 1, .8, .9)
        end
      end)
      grip:SetScript("OnDragStart", function()
        local frame = this.frame
        this.resizing = true
        this.left = frame:GetLeft() or 0
        this.right = frame:GetRight() or this.left
        this.bottom = frame:GetBottom() or 0
        this.top = frame:GetTop() or this.bottom
        this:SetScript("OnUpdate", function()
          local fr = this.frame
          local sc = UIParent:GetEffectiveScale() or 1
          local x, y = GetCursorPosition()
          x, y = x / sc, y / sc
          local left, right, top, bottom = this.left, this.right, this.top, this.bottom
          local c = this.corner
          if c == "TOPLEFT" or c == "BOTTOMLEFT" then
            left = x
          else
            right = x
          end
          if c == "TOPLEFT" or c == "TOPRIGHT" then
            top = y
          else
            bottom = y
          end
          local step = GridStep()
          local nw = right - left
          local nh = top - bottom
          if nw < step then
            if c == "TOPLEFT" or c == "BOTTOMLEFT" then
              left = right - step
            else
              right = left + step
            end
            nw = step
          end
          if nh < step then
            if c == "BOTTOMLEFT" or c == "BOTTOMRIGHT" then
              bottom = top - step
            else
              top = bottom + step
            end
            nh = step
          end
          fr:ClearAllPoints()
          fr:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
          fr:SetWidth(nw)
          fr:SetHeight(nh)
          if fr.drag and fr.drag.text then
            fr.drag.text:SetText(PixelToGrid(nw) .. "×" .. PixelToGrid(nh))
          end
          if pfUI.unlock.dock.parent and pfUI.unlock.dock.parent.frame == fr then
            UpdateDockValues()
          end
        end)
      end)
      grip:SetScript("OnDragStop", function()
        this:SetScript("OnUpdate", nil)
        this.resizing = nil
        this.texture:SetTexture(.2, 1, .8, .9)
        local frame = this.frame
        local w, h = FrameSizeCells(frame)
        ApplyUnlockSize(frame, w, h, true)
        RestoreDragLabel(frame)
        UpdateDockValues()
      end)
      table.insert(d.resizes, grip)
    end
    d.resize = d.resizes[4] -- BOTTOMRIGHT, kept for older callers

    return d
  end

  table.insert(UISpecialFrames, "pfUnlock")
  pfUI.unlock = CreateFrame("Button", "pfUnlock", UIParent)
  pfUI.unlock.selection = {}
  pfUI.unlock:Hide()
  pfUI.unlock:SetAllPoints(WorldFrame)
  pfUI.unlock:SetFrameStrata("BACKGROUND")
  pfUI.unlock:SetScript("OnClick", function()
    this:Hide()
  end)

  pfUI.unlock:SetScript("OnShow", function()
    if this.skip then this.skip = nil return end
    if InCombatLockdown and InCombatLockdown() then
      DEFAULT_CHAT_FRAME:AddMessage(ERR_NOT_IN_COMBAT, 1, .2, .2)
      this.skip = true
      this:Hide()
      return
    end

    this.grid = this.grid or DrawGrid()

    for name, frame in pairs(pfUI.movables) do
      local frame = frame or _G[name]

      if not frame:IsShown() then frame.hideLater = true end
      -- Recreate if an older single-corner drag is still attached.
      if frame.drag and not frame.drag.resizes then
        frame.drag:Hide()
        frame.drag = nil
      end
      frame.drag = frame.drag or CreateDragger(frame)
      frame:SetMovable(true)
      frame.drag:Show()
      frame:Show()
    end

    local txt = T["Unlock Mode allows you to move, size and reset frames:\n\n|cff33ffcc[Left Click]|r Drag Frame\n|cff33ffcc[Drag any Corner]|r Resize Frame\n|cff33ffcc[Middle Click]|r Reset Frame\n|cff33ffcc[Right Click]|r Option Box\n\nHold |cff33ffcc[Shift]|r same-kind frames\nHold |cff33ffcc[Ctrl]|r same-group frames\n\nDrag keeps the current anchor\n(BOTTOM = bottom edge, X from mid-line).\nNear a green mid-line, that axis snaps to 0;\nseats also snap to the grid.\nDock X/Y/W/H = grid cells; arrows nudge one cell.\nX (mid) / Y (mid) = centre-relative.\nResize snaps to whole cells (not scale).\n\n|cff33ffcc[Click]|r empty area or |cff33ffcc[Esc]|r to exit\n"]
    CreateInfoBox(txt, 15, pfUI.unlock, 300)
    pfUI.gui:Hide()
  end)

  pfUI.unlock:SetScript("OnHide", function()
    if this.skip then this.skip = nil return end
    if InCombatLockdown and InCombatLockdown() then
      this.skip = true
      this:Show()
      return
    end

    for name, frame in pairs(pfUI.movables) do
      local frame = frame or _G[name]

      if frame.hideLater == true then frame:Hide() end
      frame:StopMovingOrSizing()
      frame:SetMovable(false)
      frame.drag:Hide()
      UpdateMovable(frame)
    end

    SetDockToFrame(nil)
    pfUI.unlock:Hide()
    pfUI.gui:Show()
  end)

  -- dock frame
  pfUI.unlock.dock = CreateFrame("Button", "pfUnlockDock", pfUI.unlock)
  pfUI.unlock.dock:SetWidth(160)
  pfUI.unlock.dock:SetHeight(205)
  pfUI.unlock.dock:SetFrameStrata("FULLSCREEN_DIALOG")
  pfUI.unlock.dock:Hide()
  CreateBackdrop(pfUI.unlock.dock)

  -- title
  pfUI.unlock.dock.title = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.title:SetTextColor(1,1,1,1)
  pfUI.unlock.dock.title:SetFont(pfUI.font_default, C.global.font_size + 2, "OUTLINE")
  pfUI.unlock.dock.title:SetJustifyH("left")
  pfUI.unlock.dock.title:SetPoint("TOP", 0, -5)

  -- anchor
  pfUI.unlock.dock.anchor = CreateFrame("Frame", "pfUIUnlockAnchorDropDownMenu", pfUI.unlock.dock, "UIDropDownMenuTemplate")
  pfUI.unlock.dock.anchor:ClearAllPoints()
  pfUI.unlock.dock.anchor:SetPoint("TOP", 0, -25)

  UIDropDownMenu_SetWidth(120, pfUI.unlock.dock.anchor)
  UIDropDownMenu_SetButtonWidth(120, pfUI.unlock.dock.anchor)
  UIDropDownMenu_JustifyText("RIGHT", pfUI.unlock.dock.anchor)
  UIDropDownMenu_Initialize(pfUI.unlock.dock.anchor, function()
    local info = {}
    for id, k in pairs(anchors) do
      -- get human readable
      local value, text = strsplit(":", k)
      -- Lua 5.0: closures share the loop locals; capture per button.
      local id = id
      local value = value
      local text = text or value

      info.text = text
      info.checked = false
      info.func = function()
        UIDropDownMenu_SetSelectedID(pfUI.unlock.dock.anchor, id, 0)
        UIDropDownMenu_SetText(text, pfUI.unlock.dock.anchor)

        local frame = pfUI.unlock.dock.parent.frame
        local a, x, y = ConvertFrameAnchor(frame, value)
        x, y = SnapSeat(a, CellsFromPixel(x), CellsFromPixel(y))
        SetLogicalPoint(frame, a, x, y)

        SavePosition(frame)
        UpdateDockValues()
      end

      UIDropDownMenu_AddButton(info)
    end
  end)

  SkinDropDown(pfUI.unlock.dock.anchor)

  -- x coordinates
  pfUI.unlock.dock.xcoordcap = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.xcoordcap:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  pfUI.unlock.dock.xcoordcap:SetJustifyH("LEFT")
  pfUI.unlock.dock.xcoordcap:SetPoint("TOPLEFT", 5, -63)
  pfUI.unlock.dock.xcoordcap:SetText("X:")
  pfUI.unlock.dock.xcoord = CreateFrame("EditBox", nil, pfUI.unlock.dock)
  pfUI.unlock.dock.xcoord:SetTextInsets(5, 5, 5, 5)
  pfUI.unlock.dock.xcoord:SetJustifyH("CENTER")
  pfUI.unlock.dock.xcoord:SetWidth(42)
  pfUI.unlock.dock.xcoord:SetHeight(18)
  pfUI.unlock.dock.xcoord:SetPoint("TOPLEFT", pfUI.unlock.dock, "TOPLEFT", 32, -60)
  pfUI.unlock.dock.xcoord:SetFontObject(GameFontNormal)
  pfUI.unlock.dock.xcoord:SetAutoFocus(false)

  pfUI.unlock.dock.xcoord:SetScript("OnEnterPressed", function(self)
    local newXPos = tonumber(this:GetText())
    if newXPos then
      local frame = pfUI.unlock.dock.parent.frame
      local anchor, _, ypos = LogicalOffsets(frame)
      SetLogicalPoint(frame, anchor, newXPos, ypos)
      SavePosition(frame)
      UpdateDockValues()
    else
      UpdateDockValues()
    end
    this:ClearFocus()
  end)

  pfUI.unlock.dock.xcoord:SetScript("OnTextChanged", function(self)
    if tonumber(this:GetText()) then
      this:SetTextColor(1,1,1,1)
    else
      this:SetTextColor(1,.3,.3,1)
    end
  end)

  CreateBackdrop(pfUI.unlock.dock.xcoord, nil, true)

  -- y coordinates
  pfUI.unlock.dock.ycoordcap = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.ycoordcap:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  pfUI.unlock.dock.ycoordcap:SetText("Y:")
  pfUI.unlock.dock.ycoordcap:SetJustifyH("LEFT")
  pfUI.unlock.dock.ycoordcap:SetPoint("TOPLEFT", 80, -63)
  pfUI.unlock.dock.ycoord = CreateFrame("EditBox", nil, pfUI.unlock.dock)
  pfUI.unlock.dock.ycoord:SetTextInsets(5, 5, 5, 5)
  pfUI.unlock.dock.ycoord:SetJustifyH("CENTER")
  pfUI.unlock.dock.ycoord:SetWidth(42)
  pfUI.unlock.dock.ycoord:SetHeight(18)
  pfUI.unlock.dock.ycoord:SetPoint("TOPLEFT", pfUI.unlock.dock, "TOPLEFT", 107, -60)
  pfUI.unlock.dock.ycoord:SetFontObject(GameFontNormal)
  pfUI.unlock.dock.ycoord:SetAutoFocus(false)

  pfUI.unlock.dock.ycoord:SetScript("OnEnterPressed", function(self)
    local newYPos = tonumber(this:GetText())
    if newYPos then
      local frame = pfUI.unlock.dock.parent.frame
      local anchor, xpos = LogicalOffsets(frame)
      SetLogicalPoint(frame, anchor, xpos, newYPos)
      SavePosition(frame)
      UpdateDockValues()
    else
      UpdateDockValues()
    end
    this:ClearFocus()
  end)

  pfUI.unlock.dock.ycoord:SetScript("OnTextChanged", function(self)
    if tonumber(this:GetText()) then
      this:SetTextColor(1,1,1,1)
    else
      this:SetTextColor(1,.3,.3,1)
    end
  end)

  CreateBackdrop(pfUI.unlock.dock.ycoord, nil, true)

  -- width (grid cells)
  pfUI.unlock.dock.wcoordcap = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.wcoordcap:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  pfUI.unlock.dock.wcoordcap:SetJustifyH("LEFT")
  pfUI.unlock.dock.wcoordcap:SetPoint("TOPLEFT", 5, -88)
  pfUI.unlock.dock.wcoordcap:SetText("W:")
  pfUI.unlock.dock.wcoord = CreateFrame("EditBox", nil, pfUI.unlock.dock)
  pfUI.unlock.dock.wcoord:SetTextInsets(5, 5, 5, 5)
  pfUI.unlock.dock.wcoord:SetJustifyH("CENTER")
  pfUI.unlock.dock.wcoord:SetWidth(42)
  pfUI.unlock.dock.wcoord:SetHeight(18)
  pfUI.unlock.dock.wcoord:SetPoint("TOPLEFT", pfUI.unlock.dock, "TOPLEFT", 32, -85)
  pfUI.unlock.dock.wcoord:SetFontObject(GameFontNormal)
  pfUI.unlock.dock.wcoord:SetAutoFocus(false)
  pfUI.unlock.dock.wcoord:SetScript("OnEnterPressed", function()
    local newW = tonumber(this:GetText())
    local frame = pfUI.unlock.dock.parent and pfUI.unlock.dock.parent.frame
    if newW and frame then
      local _, h = FrameSizeCells(frame)
      ApplyUnlockSize(frame, newW, h, false)
      UpdateDockValues()
    else
      UpdateDockValues()
    end
    this:ClearFocus()
  end)
  pfUI.unlock.dock.wcoord:SetScript("OnTextChanged", function()
    if tonumber(this:GetText()) then
      this:SetTextColor(1,1,1,1)
    else
      this:SetTextColor(1,.3,.3,1)
    end
  end)
  CreateBackdrop(pfUI.unlock.dock.wcoord, nil, true)

  -- height (grid cells)
  pfUI.unlock.dock.hcoordcap = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.hcoordcap:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  pfUI.unlock.dock.hcoordcap:SetJustifyH("LEFT")
  pfUI.unlock.dock.hcoordcap:SetPoint("TOPLEFT", 80, -88)
  pfUI.unlock.dock.hcoordcap:SetText("H:")
  pfUI.unlock.dock.hcoord = CreateFrame("EditBox", nil, pfUI.unlock.dock)
  pfUI.unlock.dock.hcoord:SetTextInsets(5, 5, 5, 5)
  pfUI.unlock.dock.hcoord:SetJustifyH("CENTER")
  pfUI.unlock.dock.hcoord:SetWidth(42)
  pfUI.unlock.dock.hcoord:SetHeight(18)
  pfUI.unlock.dock.hcoord:SetPoint("TOPLEFT", pfUI.unlock.dock, "TOPLEFT", 107, -85)
  pfUI.unlock.dock.hcoord:SetFontObject(GameFontNormal)
  pfUI.unlock.dock.hcoord:SetAutoFocus(false)
  pfUI.unlock.dock.hcoord:SetScript("OnEnterPressed", function()
    local newH = tonumber(this:GetText())
    local frame = pfUI.unlock.dock.parent and pfUI.unlock.dock.parent.frame
    if newH and frame then
      local w = FrameSizeCells(frame)
      ApplyUnlockSize(frame, w, newH, false)
      UpdateDockValues()
    else
      UpdateDockValues()
    end
    this:ClearFocus()
  end)
  pfUI.unlock.dock.hcoord:SetScript("OnTextChanged", function()
    if tonumber(this:GetText()) then
      this:SetTextColor(1,1,1,1)
    else
      this:SetTextColor(1,.3,.3,1)
    end
  end)
  CreateBackdrop(pfUI.unlock.dock.hcoord, nil, true)

  -- reset button
  pfUI.unlock.dock.reset = CreateFrame("Button", "pfDragDockReset", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.reset:SetHeight(18)
  pfUI.unlock.dock.reset:SetPoint("TOPLEFT", 5, -110)
  pfUI.unlock.dock.reset:SetPoint("TOPRIGHT", -5, -110)
  pfUI.unlock.dock.reset:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame

    if this:GetText() == T["Reset"] then
      local name = frame:GetName()
      pfUI_config["position"][name] = nil
      frame.pfAnchor = nil
      frame:ClearAllPoints()
      if frame.config and frame.posdata then
        if frame.posdata.cfgWidth then frame.config.width = frame.posdata.cfgWidth end
        if frame.posdata.cfgHeight then frame.config.height = frame.posdata.cfgHeight end
        if frame.UpdateConfig then frame:UpdateConfig() end
      end
      local bar = ActionBarId(name)
      if bar and C.bars and C.bars["bar"..bar] and frame.posdata then
        if frame.posdata.icon_size then
          C.bars["bar"..bar].icon_size = frame.posdata.icon_size
        end
        if frame.posdata.formfactor then
          C.bars["bar"..bar].formfactor = frame.posdata.formfactor
        end
        if pfUI.bars and pfUI.bars.UpdateConfig then pfUI.bars:UpdateConfig() end
      end
      UpdateMovable(frame)
    else
      -- Bake the current visual into a saved seat without keeping the
      -- StartMoving TOPLEFT-vs-screen pin as the stored anchor.
      local a, x, y = ConvertFrameAnchor(frame, GetBestAnchor(frame) or "TOPLEFT")
      x, y = SnapSeat(a, CellsFromPixel(x), CellsFromPixel(y))
      SetLogicalPoint(frame, a, x, y)
      SavePosition(frame)
    end

    if frame.OnMove then frame:OnMove() end

    QueueFunction(SetDockToFrame, pfUI.unlock.dock.parent)
  end)
  SkinButton(pfUI.unlock.dock.reset,.2,1,.8)

  -- move left
  pfUI.unlock.dock.left = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.left:SetHeight(18)
  pfUI.unlock.dock.left:SetWidth(18)
  pfUI.unlock.dock.left:SetPoint("TOP", -50, -135)
  pfUI.unlock.dock.left.texture = pfUI.unlock.dock.left:CreateTexture("arrow")
  pfUI.unlock.dock.left.texture:SetTexture(pfUI.media["img:left"])
  pfUI.unlock.dock.left.texture:ClearAllPoints()
  pfUI.unlock.dock.left.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.left, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.left.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.left, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.left:SetScript("OnClick", function()
    NudgeFrame(-1, 0)
  end)
  SkinButton(pfUI.unlock.dock.left,.2,1,.8)

  -- move right
  pfUI.unlock.dock.right = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.right:SetHeight(18)
  pfUI.unlock.dock.right:SetWidth(18)
  pfUI.unlock.dock.right:SetPoint("TOP", -25, -135)
  pfUI.unlock.dock.right.texture = pfUI.unlock.dock.right:CreateTexture("arrow")
  pfUI.unlock.dock.right.texture:SetTexture(pfUI.media["img:right"])
  pfUI.unlock.dock.right.texture:ClearAllPoints()
  pfUI.unlock.dock.right.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.right, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.right.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.right, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.right:SetScript("OnClick", function()
    NudgeFrame(1, 0)
  end)
  SkinButton(pfUI.unlock.dock.right,.2,1,.8)

  -- move up
  pfUI.unlock.dock.up = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.up:SetHeight(18)
  pfUI.unlock.dock.up:SetWidth(18)
  pfUI.unlock.dock.up:SetPoint("TOP", 25, -135)
  pfUI.unlock.dock.up.texture = pfUI.unlock.dock.up:CreateTexture("arrow")
  pfUI.unlock.dock.up.texture:SetTexture(pfUI.media["img:up"])
  pfUI.unlock.dock.up.texture:ClearAllPoints()
  pfUI.unlock.dock.up.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.up, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.up.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.up, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.up:SetScript("OnClick", function()
    NudgeFrame(0, 1)
  end)
  SkinButton(pfUI.unlock.dock.up,.2,1,.8)

  -- move down
  pfUI.unlock.dock.down = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.down:SetHeight(18)
  pfUI.unlock.dock.down:SetWidth(18)
  pfUI.unlock.dock.down:SetPoint("TOP", 50, -135)
  pfUI.unlock.dock.down.texture = pfUI.unlock.dock.down:CreateTexture("arrow")
  pfUI.unlock.dock.down.texture:SetTexture(pfUI.media["img:down"])
  pfUI.unlock.dock.down.texture:ClearAllPoints()
  pfUI.unlock.dock.down.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.down, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.down.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.down, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.down:SetScript("OnClick", function()
    NudgeFrame(0, -1)
  end)
  SkinButton(pfUI.unlock.dock.down,.2,1,.8)

  -- open config
  pfUI.unlock.dock.config = CreateFrame("Button", "pfDragDockConfigOpen", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.config:SetHeight(18)
  pfUI.unlock.dock.config:SetPoint("BOTTOMLEFT", 5, 5)
  pfUI.unlock.dock.config:SetPoint("BOTTOMRIGHT", -5, 5)
  pfUI.unlock.dock.config:SetText(T["Configure"])
  pfUI.unlock.dock.config:SetScript("OnClick", function()
    local cat, conf = GetConfigTable(pfUI.unlock.dock.parent.label)
    if cat then OpenConfigDialog(cat, conf) end
  end)
  SkinButton(pfUI.unlock.dock.config,.2,1,.8)
end)
