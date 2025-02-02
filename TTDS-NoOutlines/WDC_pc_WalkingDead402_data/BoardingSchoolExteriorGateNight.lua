﻿local kScript = "BoardingSchoolExteriorGateNight"
local kScene = "adv_boardingSchoolExteriorGateNight"
local kRaiderLimits = {
  xMin = 0.25,
  xMax = 0.75,
  yMin = 0.35,
  yMax = 0.65
}
local mbHardMode = false
local mbClemWonLastRound = false
local mbTimedOut = false
local mbAJRuthless, mLastAJPick, mLastClemPick
local mRPSWins = 0
local mRPSLosses = 0
local mConsecutiveDraws = 0
local mRaiderMonitorThread
local OnLogicReady = function()
  if Game_GetLoaded() then
    return
  end
  Episode_SetAbelArm()
  Episode_SetAJShirt()
  mbAJRuthless = not LogicGet("1 - AJ Compassionate")
  if LogicGet("Episode 401 - Let AJ Cuss") then
    LogicSet("3 - AJ Cussing Level", 9001)
  end
  if LogicGet("Debug ID") == 1 then
    Game_SetSceneDialogNode("cs_rockPaperScissors")
  end
end
local LookingAt = function(agent)
  local pos = AgentGetLogicalScreenPos(agent)
  if not pos or AgentIsHidden(agent) or not AgentIsOnScreen(agent) then
    return false
  end
  return pos.x >= kRaiderLimits.xMin and pos.x <= kRaiderLimits.xMax and pos.y >= kRaiderLimits.yMin and pos.y <= kRaiderLimits.yMax
end
local RaiderSearch = function(agent)
  local elapsedTime = 0
  local timeBuffer = 1.5
  while true do
    if Game_IsPlayMode() then
      if LookingAt(agent) then
        elapsedTime = elapsedTime + GetFrameTime() * SceneGetTimeScale(kScene)
        if timeBuffer <= elapsedTime then
          break
        end
      else
        elapsedTime = 0
      end
    end
    WaitForNextFrame()
  end
  Game_RunSceneDialog("cs_exit")
end


--a custom function that makes it easier to change properties on a scene agent
Custom_AgentSetProperty = function(agentName, propertyString, propertyValue, sceneObject)

    --find the agent within the scene
    local agent = AgentFindInScene(agentName, sceneObject)
    
    --get the runtime properties of that agent
    local agent_props = AgentGetRuntimeProperties(agent)
    
    --set the given (propertyString) on the agent to (propertyValue)
    PropertySet(agent_props, propertyString, propertyValue)
end

--removes an agent from a scene
Custom_RemoveAgent = function(agentName, sceneObj)
    --check if the agent exists
    if AgentExists(AgentGetName(agentName)) then
        --find the agent
        local agent = AgentFindInScene(agentName, sceneObj)
        
        --destroy the agent
        AgentDestroy(agent)
   end
end

--our main function which we will do our scene modifications in
ModifyScene = function(sceneObj)

    --set some properties on the scene
    local sceneName = sceneObj .. ".scene"
    Custom_AgentSetProperty(sceneName, "Generate NPR Lines", false, sceneObj)
    Custom_AgentSetProperty(sceneName, "Screen Space Lines - Enabled", false, sceneObj)
    
    --removes the green-brown graduated filter on the scene
    Custom_RemoveAgent("module_post_effect", sceneObj)
    
    --force graphic black off in this scene
    local prefs = GetPreferences()
    PropertySet(prefs, "Enable Graphic Black", false)
    PropertySet(prefs, "Render - Graphic Black Enabled", false)
end

function BoardingSchoolExteriorGateNight()
    ModifyScene(kScene)
end


function BoardingSchoolExteriorGateNight_BestOf3()
  if mRPSWins == mRPSLosses or mRPSWins + mRPSLosses < 2 then
    Game_RunSceneDialog("cs_nextRound")
    return
  elseif mRPSWins > mRPSLosses then
    Game_RunSceneDialog("cs_clemWins")
  else
    Game_RunSceneDialog("cs_ajWins")
  end
  mRPSWins = 0
  mRPSLosses = 0
end
function BoardingSchoolExteriorGateNight_ClemThrow(clemPick)
  local GetWinner = function(move)
    return (move + 1) % 3
  end
  local GetLoser = function(move)
    return (move - 1) % 3
  end
  local ajPick
  if mbHardMode or not mLastClemPick then
    ajPick = RandomInt(0, 2)
  elseif mbTimedOut or mConsecutiveDraws >= 1 then
    if mbAJRuthless then
      ajPick = GetWinner(clemPick)
    else
      ajPick = GetLoser(clemPick)
    end
  elseif mbClemWonLastRound then
    if mbAJRuthless then
      ajPick = GetWinner(GetWinner(mLastClemPick))
    else
      ajPick = GetWinner(mLastClemPick)
    end
  elseif mbAJRuthless then
    ajPick = GetWinner(GetWinner(mLastAJPick))
  else
    ajPick = LogicGet("3 - AJ RPS Pick")
  end
  mLastClemPick = clemPick
  mLastAJPick = ajPick
  LogicSet("3 - AJ RPS Pick", ajPick)
  LogicIncrement("3 - RPS Rounds")
  Game_RunDialog("logic_ajThrow")
end
function BoardingSchoolExteriorGateNight_EndRound(bWin)
  mbTimedOut = false
  if bWin == true then
    mRPSWins = mRPSWins + 1
    mConsecutiveDraws = 0
  elseif bWin == false then
    mRPSLosses = mRPSLosses + 1
    mConsecutiveDraws = 0
  else
    mConsecutiveDraws = mConsecutiveDraws + 1
  end
end
function BoardingSchoolExteriorGateNight_Timeout()
  mbTimedOut = true
end
function BoardingSchoolExteriorGateNight_EnableRaiderSearch(bEnable)
  if bEnable == ThreadIsRunning(mRaiderMonitorThread) then
    return
  elseif bEnable == false then
    mRaiderMonitorThread = ThreadKill(mRaiderMonitorThread)
  else
    mRaiderMonitorThread = ThreadStart(RaiderSearch, "dummy_raider")
  end
end
Callback_OnLogicReady:Add(OnLogicReady)
Game_SceneOpen(kScene, kScript)
