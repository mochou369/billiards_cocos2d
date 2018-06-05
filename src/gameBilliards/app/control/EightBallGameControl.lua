EBGameControl = EBGameControl or {}
--EBGameControl.__index = EBGameControl

local m_MainLayer
function EBGameControl:init()
end

function EBGameControl:setCueRotationOwn(cue,rotate)
    cue:setRotationOwn(rotate,m_MainLayer)
end

--发射球
function EBGameControl:givePowerToWhiteBall(_forcePercent)
    if m_MainLayer and m_MainLayer.whiteBall then
        local cueRotation = m_MainLayer.cue:getRotation()
        local ballRotation = m_MainLayer.whiteBall:getRotation()
        local rot = cueRotation-ballRotation
        m_MainLayer.cue:setVisible(false)
    end
end

--比赛开始了
function EBGameControl:startGame(rootNode)
    print("start game in eightball game control ")
    PhyControl:resetAllBallsPos(rootNode)
    rootNode.cue:setRotationOwn(0,rootNode)
    if EBGameControl:getGameState() == g_EightBallData.gameState.practise then
        BilliardsAniMgr:setSliderBarAni(true,m_MainLayer)
        BilliardsAniMgr:setFineTurningAni(true,m_MainLayer)
        BilliardsAniMgr:setDeskTempAni(m_MainLayer,true)  --桌子白板
    end
    ----------------------------------------------------------------------------------
--   --测试
--   for i=1,5 do
--       rootNode.desk:getChildByTag(i):setPosition(cc.p(1500,1500))
--   end
--   rootNode.desk:getChildByTag(6):setPosition(cc.p(100,100))
--   rootNode.desk:getChildByTag(7):setPosition(cc.p(800,100))
--   rootNode.desk:getChildByTag(8):setPosition(cc.p(450,100))
    ----------------------------------------------------------------------------------
end

--退出游戏处理
function EBGameControl:leaveGame()
    os.exit()
end

--处理白球进洞,放回原始位置
function EBGameControl:dealWhiteBallInHole()
    print("EBGameControl:dealWhiteBallInHole()====")
    m_MainLayer.whiteBall:resetForceAndEffect()
    m_MainLayer.whiteBall:resetBallState()
    m_MainLayer.whiteBall:setBallState(g_EightBallData.ballState.stop)
    local pos = cc.p(270, m_MainLayer.desk:getContentSize().height / 2)
    while true do
        if not mathMgr:checkBallLocationIsLegal(m_MainLayer, pos, m_MainLayer.whiteBall) then
            pos.x = pos.x + m_MainLayer.whiteBall:getContentSize().width + 5
        else
            break
        end
    end
    m_MainLayer.whiteBall:setPosition(pos)
    m_MainLayer.whiteBall:dealWhiteBallInHole(m_MainLayer)
end

-- 获取各色球是否都进洞了
--@param nType = 1 全色球 nType = 2 半色球 3 所有球
function EBGameControl:getIsBallAllInHole(nType)
    local ball
    local isAllInHole = false
    if nType == 1 then
        for i=1,7 do
            ball = m_MainLayer.desk:getChildByTag(i)
            if ball then
                if not ball:getIsInHole() then
                    return false
                end
            end
        end
        return true
    elseif nType == 2 then
        for i=9,15 do
            ball = m_MainLayer.desk:getChildByTag(i)
            if ball then
                if not ball:getIsInHole() then
                    return false
                end
            end
        end
        return true
    end
    return false
end

--获取所有球是否停止
function EBGameControl:getIsBallAllStop()
    local ball
    for i = 1, 15 do
        ball = m_MainLayer.desk:getChildByTag(i)
        if ball then
            if not ball:checkIsStop() then
                return false
            end
        end
    end
    return true
end

--设置所有球的标记函数为run
--击打球的时候调用,优化性能
function EBGameControl:setAllBallsRun()
    local ball
    for i=0,15 do
        ball = m_MainLayer.desk:getChildByTag(i)
        if ball:getBallState() ~= g_EightBallData.ballState.inHole then
            ball:setBallState(g_EightBallData.ballState.run)
        end
    end
end

--处理断线重连,只是同步一下所有信息
function EBGameControl:dealGameResume(event)
    local array = { }
    array.RountCount = event.RoundCount
    array.UserID = event.CurrentUserID
    array.FullColorUserID = event.FullColorBallUserID
    array.HalfColorUserID = event.HalfColorBallUserID
    array.Result = event.GameState
    array.LinkCount = event.LinkCount
    array.BallInfoArray = event.Balls
    EightBallGameManager:clearBallsProcess()
    EightBallGameManager:setBallsResultPos(array)
    EBGameControl:setGameState(g_EightBallData.gameState.none)
    EightBallGameManager:syncHitResult(m_MainLayer, true)
    m_MainLayer.whiteBall:setPosition(cc.p(GetPreciseDecimal(event.Balls[1].fPositionX), GetPreciseDecimal(event.Balls[1].fPositionY)))
    m_MainLayer.whiteBall:setRotationOwn(event.WhiteBallRotation)
    BilliardsAniMgr:setDeskTempAni(m_MainLayer, false)
    if m_MainLayer.whiteBall:getIsInHole() then
        EBGameControl:dealWhiteBallInHole()
    end
    m_MainLayer.cue:setRotationOwn(0,m_MainLayer)
    EightBallGameManager:setCanRefreshBallAni(true)  --设置可以刷新球3D特效
    
    --定时器条
    local progressTimer1 = player:getPlayerUserID() == event.CurrentUserID and m_MainLayer.profressTimer1 or m_MainLayer.profressTimer2
    local progressTimer2 = player:getPlayerUserID() == event.CurrentUserID and m_MainLayer.profressTimer2 or m_MainLayer.profressTimer1
    BilliardsAniMgr:setHeadTimerAni(progressTimer1,event.LeftTime,nil)
    BilliardsAniMgr:setHeadTimerAni(progressTimer2,0,nil)
end

--球落袋了
function EBGameControl:ballInHole(nTag, nNode)
    print(nTag .. " num ball is in hole",m_MainLayer.desk:getChildByTag(0):getBallState())
    EightBallGameManager:dealInHoleToServer(nTag)
    local ball = m_MainLayer.desk:getChildByTag(nTag)
    if ball and nNode then
        ball:setBallState(g_EightBallData.ballState.inHole,m_MainLayer)
        -- 球进洞(设置一下ballState)
        local ballPosX, ballPosY = ball:getPosition()
        local nodePosX, nodePosY = nNode:getPosition()
        ball:getPhysicsBody():resetForces()
        ball:getPhysicsBody():setVelocity(cc.p(0, 0))
        ball:getPhysicsBody():setAngularVelocity(0)
        local sprite3d = ball:getChildByTag(g_EightBallData.g_Border_Tag.texture3D)
        if sprite3D and sprite3D:getPhysicsObj() then
            sprite3D:getPhysicsObj():setAngularVelocity(cc.vec3(0.0, 0.0, 0.0))
        end
        -- 取消碰撞
        ball:getPhysicsBody():setCategoryBitmask(0x04)
        ball:getPhysicsBody():setContactTestBitmask(0x04)
        ball:getPhysicsBody():setCollisionBitmask(0x04)

        ball:runAction(cc.Spawn:create(cc.MoveTo:create(0.5, cc.p(nodePosX, nodePosY)), cc.ScaleTo:create(0.5, 0.7), cc.CallFunc:create( function()
            if sprite3D and sprite3D:getPhysicsObj() then
                sprite3D:getPhysicsObj():setAngularVelocity(cc.vec3(-(nodePosY - ballPosY) / g_EightBallData.ballRollingRate / 20,(nodePosX - ballPosX) / g_EightBallData.ballRollingRate / 20, 0.0))
            end
        end )))

        ball:runAction(cc.Sequence:create(cc.DelayTime:create(0.5), cc.CallFunc:create( function()
            if ball and not tolua.isnull(ball) then
                ball:resetBallState()
                ball:setPosition(cc.p(1500, 1500))
                --ball:setBallState(g_EightBallData.ballState.inHole)

                -- 碰撞最后加上
                ball:getPhysicsBody():setCategoryBitmask(0x01)
                ball:getPhysicsBody():setContactTestBitmask(0x01)
                ball:getPhysicsBody():setCollisionBitmask(0x03)

                if ball:getTag() == 0 then
                    print("white ball in hole animation is done",ball:getIsInHole())

                    if ball:getIsInHole() then
                        if EightBallGameManager:getIsSyncHitResult() and EBGameControl:getIsBallAllStop() and m_MainLayer:isTimeEnteryStop() then
                            EBGameControl:dealWhiteBallInHole()  -- 处理白球落袋
                        end
                    end

                -- EBGameControl:dealWhiteBallInHole()--处理白球落袋
                elseif ball:getTag() == 8 then
                    tool.openNetTips("黑八进啦，比赛结束了")
                end
            end
        end )))

        if nTag > 0 and nTag <= 15 then
            ball:runAction(cc.Sequence:create(cc.DelayTime:create(1), cc.CallFunc:create( function()
                ball:dealBallInBag()
            end )))
        end
    end
end

-- 处理指示球
function EBGameControl:dealTipBalls()
    if EBGameControl:getGameState() == g_EightBallData.gameState.practise then
        return
    end
    local full, half = EightBallGameManager:getColorUserID()
    local myColor =(full ~= -1 and half ~= -1) and(full == player:getPlayerUserID() and 1 or 2) or -1
    local tipBall
    local ball

    local function newBalls(root, rootPos, index)
        tipBall = ccui.ImageView:create("gameBilliards/eightBall/ball_" .. index .. ".png", UI_TEX_TYPE_LOCAL)
        tipBall:setScale(0.6)
        tipBall:setTag(index)
        root:addChild(tipBall)
        tipBall:setPosition(cc.p(rootPos:getPositionX() +(index < 8 and(index - 1) or(index - 9)) * 43.1, rootPos:getPositionY()))
    end

    local function checkVisible(pTipBall, index)
        ball = m_MainLayer.desk:getChildByTag(index)
        if ball and ball:getBallState() == g_EightBallData.ballState.inHole then
            pTipBall:setVisible(false)
        else
            pTipBall:setVisible(true)
        end
    end

    if myColor == 1 then
        for i = 1, 7 do
            tipBall = m_MainLayer.img_User1:getChildByTag(i)
            if not tipBall then
                newBalls(m_MainLayer.img_User1, m_MainLayer.tipBall1, i)
            end
            checkVisible(tipBall, i)
        end
        for i = 9, 15 do
            tipBall = m_MainLayer.img_User2:getChildByTag(i)
            if not tipBall then
                newBalls(m_MainLayer.img_User2, m_MainLayer.tipBall2, i)
            end
            checkVisible(tipBall, i)
        end
    elseif myColor == 2 then
        for i = 1, 7 do
            tipBall = m_MainLayer.img_User2:getChildByTag(i)
            if not tipBall then
                newBalls(m_MainLayer.img_User2, m_MainLayer.tipBall2, i)
            end
            checkVisible(tipBall, i)
        end
        for i = 9, 15 do
            tipBall = m_MainLayer.img_User1:getChildByTag(i)
            if not tipBall then
                newBalls(m_MainLayer.img_User1, m_MainLayer.tipBall1, i)
            end
            checkVisible(tipBall, i)
        end
    end
end

--碰撞监听初始化
function EBGameControl:initCheckCollisionListener(root)
    m_MainLayer = root
    local function onContactBegin(contact)
        if contact and not tolua.isnull(contact) and contact:getShapeA() and contact:getShapeB() then
            local nodeA = contact:getShapeA():getBody():getNode()
            local nodeB = contact:getShapeB():getBody():getNode()
            local tagA = nodeA:getTag()
            local tagB = nodeB:getTag()
            --_print("collision tags are ",tagA,tagB)
            local velocityA = math.abs(nodeA:getPhysicsBody():getVelocity().x) + math.abs(nodeA:getPhysicsBody():getVelocity().y)
            local velocityB = math.abs(nodeB:getPhysicsBody():getVelocity().x) + math.abs(nodeB:getPhysicsBody():getVelocity().y)
            local velocity = velocityA + velocityB
            EightBallGameManager:playEffectByTag(tagA,tagB,velocity) --播放音效

            EightBallGameManager:dealCollisionToServer(tagA,tagB)

            if nodeA and nodeB and tagA <= 15 and tagB <= 15 and tagA > 0 and tagB > 0 and
            nodeA:getBallState() == g_EightBallData.ballState.inHole and nodeB:getBallState() == g_EightBallData.ballState.inHole then
                PhyControl:dealInHoleBallCollision(nodeA,nodeB,m_MainLayer.desk)
            end

            if tagA == g_EightBallData.g_Border_Tag.whiteBall or tagB == g_EightBallData.g_Border_Tag.whiteBall then
                m_MainLayer:runAction(cc.Sequence:create(cc.DelayTime:create(0.3), cc.CallFunc:create( function()
                    if m_MainLayer.whiteBall and not tolua.isnull(m_MainLayer.whiteBall) then
                        m_MainLayer.whiteBall:getPhysicsBody():resetForces()
                    end
                end )))
            end
            if tagA == 200 or tagB == 200 then
                local inHoleBallTag =(tagA == 200) and tagB or tagA
                local holeNode =((inHoleBallTag == tagA) and { contact:getShapeB():getBody():getNode() } or { contact:getShapeA():getBody():getNode() })[1]
                EBGameControl:ballInHole(inHoleBallTag, holeNode)
            end
        end
        return true
    end
    local function onContactEnd(contact)
        m_MainLayer:refreshBallAni(true)
    end
    local contactListener = cc.EventListenerPhysicsContact:create()
    contactListener:registerScriptHandler(onContactBegin, cc.Handler.EVENT_PHYSICS_CONTACT_BEGIN)
    contactListener:registerScriptHandler(onContactEnd, cc.Handler.EVENT_PHYSICS_CONTACT_SEPARATE)
    local eventDispatcher = m_MainLayer.node:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(contactListener, m_MainLayer.node)
end

--移动白球sprite的监听事件设置
function EBGameControl:setMoveWhiteBallListener()
    local function onTouchWhiteBallBegan(touch, event)
        -- 不要忘了return true  否则你懂的（事件不能响应）
        print("onTouchBegan")
        return true
    end
    local function onTouchWhiteBallEnded(touch, event)
        print("onTouchEnded")
    end
    local function onTouchWhiteBallMoved(touch, event)
        print("onTouchMoved")
        local target = event:getCurrentTarget()
        local locationInNode = target:convertToNodeSpace(touch:getLocation())
        local s = target:getContentSize()
        local rect = cc.rect(-s.width*3, -s.height*3, s.width*6, s.height*6)
        if cc.rectContainsPoint(rect, locationInNode) then
            local target = event:getCurrentTarget()
            -- 获取当前的控件
            --print("onTouchMoved : getCurrentTarget = ", target:getTag())
            local posX, posY = target:getPosition()
            -- 获取当前的位置
            local delta = touch:getDelta()
            -- 获取滑动的距离
            target:setPosition(cc.p(posX + delta.x, posY + delta.y))
            -- 给精灵重新设置位置
        end
    end
    m_MainLayer.listenerWhiteBallMove = cc.EventListenerTouchOneByOne:create()
    -- 创建一个单点事件监听
    m_MainLayer.listenerWhiteBallMove:setSwallowTouches(true)
    -- 是否向下传递
    m_MainLayer.listenerWhiteBallMove:registerScriptHandler(onTouchWhiteBallBegan, cc.Handler.EVENT_TOUCH_BEGAN)
    m_MainLayer.listenerWhiteBallMove:registerScriptHandler(onTouchWhiteBallMoved, cc.Handler.EVENT_TOUCH_MOVED)
    m_MainLayer.listenerWhiteBallMove:registerScriptHandler(onTouchWhiteBallEnded, cc.Handler.EVENT_TOUCH_ENDED)
    m_MainLayer.eventDispatcher = m_MainLayer:getEventDispatcher()
    m_MainLayer.eventDispatcher:addEventListenerWithSceneGraphPriority(m_MainLayer.listenerWhiteBallMove, m_MainLayer.whiteBall)
    -- 分发监听事件
end

-- 移除白球精灵移动事件
function EBGameControl:removMoveeWhiteBallListener()
    if m_MainLayer.eventDispatcher then
        m_MainLayer.eventDispatcher:removeEventListener(m_MainLayer.listenerWhiteBallMove)
        m_MainLayer.eventDispatcher = nil
    end
end

--击球结束后设置正确的求位置
function EBGameControl:setSuitCuePos()
    if EBGameControl:getGameState() == g_EightBallData.gameState.practise and EightBallGameManager:getCurrentUserID() == player:getPlayerUserID() then
        m_MainLayer.cue:setRotationOwn(0, m_MainLayer)
    else
        local whiteBall = m_MainLayer.whiteBall
        m_MainLayer.cue:setRotationOwn(0, m_MainLayer)
        local ball
        local suitBallDistance
        local suitBallIndex
        local myColor = EightBallGameManager:getMyColor()
        local suitBallArray = { }

        local function getSuitBallIndex(i)
            ball = m_MainLayer.desk:getChildByTag(i)
            if ball and ball:getBallState() ~= g_EightBallData.ballState.inHole then
                local _dis = mathMgr.getDistancePow2(whiteBall:getPositionX(), whiteBall:getPositionY(), ball:getPositionX(), ball:getPositionY())
                if suitBallDistance then
                    if suitBallDistance > _dis then
                        suitBallDistance = _dis
                        suitBallIndex = i
                    end
                else
                    suitBallDistance = _dis
                    suitBallIndex = i
                end
            end
        end

        local function setSuitBall()
            local suitBall = m_MainLayer.desk:getChildByTag(suitBallIndex)
            local pos = cc.p(suitBall:getPositionX(), suitBall:getPositionY())
            if m_MainLayer and m_MainLayer.whiteBall and not tolua.isnull(m_MainLayer.whiteBall) and m_MainLayer.whiteBall.getPosition then
                ballX, ballY = m_MainLayer.whiteBall:getPosition()
            else
                return
            end
            local rotate = mathMgr:getAngularByTouchPosAndBallPos(pos, ballX, ballY)
            rotate = GetPreciseDecimal(rotate)
            m_MainLayer.cue:setRotationOwn(rotate - m_MainLayer.whiteBall:getRotation(), m_MainLayer)
            --这里考虑不发送
            m_MainLayer.cue:sendSetCueMessage(rotate - m_MainLayer.whiteBall:getRotation(), m_MainLayer, true)
        end

        ---------------------------------------------------------
        ---- 测试代码
        -- myColor = 1
        ---------------------------------------------------------

        if myColor == 1 then
            for i = 1, 7 do
                getSuitBallIndex(i)
            end
            setSuitBall()
            return
        elseif myColor == 2 then
            for i = 9, 15 do
                getSuitBallIndex(i)
            end
            setSuitBall()
            return
        elseif myColor == 3 then
            ball = m_MainLayer:getChildByTag(8)
            if ball and ball:getBallState() ~= g_EightBallData.ballState.inHole then
                suitBallIndex = 8
                setSuitBall()
                return
            end
        else

        end
    end
end

local isMoved = false  --判断是否有移动
local BeganRotate = 0  --判断开始时杆的角度
local oldRotate = 0  --记录move的旧角度，为了转正确的度数，每次记录，下次在这个变量的基础上增加或者减少角度
local isReverse = false  --判断点击的是杆子正面还是反向，方向不同
--摆放杆的位置
--@ pos 触摸点位置，worldSpace
--@ isBegan 是否是开始点击事件
--@ isEnd 是否是点击结束事件
--@ angular 角度微调
--这里较乱，待整理优化
function EBGameControl:setCuePosByTouch(pos, isBegan, isEnd, angular)
    --杆子移动前先清除白球上的提示视图
    m_MainLayer.whiteBall:clearWhiteBallView()
    --fine turning angular
    if angular then
        if math.abs(angular) > 0.3 then
            return
        end
        local rotate = m_MainLayer.cue:getRotation()+angular
        BeganRotate = GetPreciseDecimal(rotate)
        m_MainLayer.cue:setRotationOwn(rotate,m_MainLayer)
        m_MainLayer.cue:sendSetCueMessage(rotate,m_MainLayer)
        return
    end
    pos = m_MainLayer.desk:convertToNodeSpace(cc.p(pos.x,pos.y))
    --touch is begun
    if isBegan then
        local ballX, ballY
        if m_MainLayer and m_MainLayer.whiteBall and not tolua.isnull(m_MainLayer.whiteBall) and m_MainLayer.whiteBall.getPosition then
            ballX, ballY = m_MainLayer.whiteBall:getPosition()
        else
            return false
        end
        BeganRotate = mathMgr:getAngularByTouchPosAndBallPos(pos, ballX, ballY)
        BeganRotate = GetPreciseDecimal(BeganRotate)
        oldRotate = 0
        return
    end
    --touch is ended
    if not isMoved and isEnd and oldRotate == 0 then
        local ballX, ballY
        BeganRotate = 0
        if m_MainLayer and m_MainLayer.whiteBall and not tolua.isnull(m_MainLayer.whiteBall) and m_MainLayer.whiteBall.getPosition then
            ballX, ballY = m_MainLayer.whiteBall:getPosition()
        else
            return false
        end
        local rotate = mathMgr:getAngularByTouchPosAndBallPos(pos, ballX, ballY)
        rotate = GetPreciseDecimal(rotate)
        m_MainLayer.cue:setRotationOwn(rotate-m_MainLayer.whiteBall:getRotation(),m_MainLayer)
        m_MainLayer.cue:sendSetCueMessage(rotate-m_MainLayer.whiteBall:getRotation(),m_MainLayer,true)
        oldRotate = 0
    end
    --touch is ended and must send cmd
    if not isMoved and isEnd then
        local angle = m_MainLayer.cue:getRotation()
        angle = GetPreciseDecimal(angle)
        m_MainLayer.cue:sendSetCueMessage(angle,m_MainLayer,true)
        return
    end
    --touch is moved
    if isMoved and not isBegan and not isEnd then
        local ballX, ballY
        if m_MainLayer and m_MainLayer.whiteBall and not tolua.isnull(m_MainLayer.whiteBall) and m_MainLayer.whiteBall.getPosition then
            ballX, ballY = m_MainLayer.whiteBall:getPosition()
        else
            return false
        end
        local rotate = mathMgr:getAngularByTouchPosAndBallPos(pos, ballX, ballY)
        if isReverse then
            local angle = BeganRotate + oldRotate - rotate + m_MainLayer.cue:getRotation()
            angle = GetPreciseDecimal(angle)
            m_MainLayer.cue:setRotationOwn(angle,m_MainLayer)
            --m_MainLayer.cue:sendSetCueMessage(angle,m_MainLayer)
        else
            local _rot = rotate - BeganRotate - oldRotate + m_MainLayer.cue:getRotation()
            if _rot < 0 then
                _rot = _rot + 360
            elseif _rot > 360 then
                _rot = _rot - 360
            end
            _rot = GetPreciseDecimal(_rot)
            m_MainLayer.cue:setRotationOwn(_rot,m_MainLayer)
            --m_MainLayer.cue:sendSetCueMessage(_rot,m_MainLayer)
        end
        oldRotate = rotate - BeganRotate
        return
    end
end

--创建监听
--@ root 场景self传入
--@ root引用保留
function EBGameControl:initListener(root)
    m_MainLayer = root
    local onBegan = function(touch, event) return EBGameControl:onTouchBegan(touch, event) end
    local onMoved = function(touch, event) EBGameControl:onTouchMoved(touch, event) end
    local onEnded = function(touch, event) EBGameControl:onTouchEnded(touch, event) end

    m_MainLayer.listenerCueRotate = cc.EventListenerTouchOneByOne:create()
    m_MainLayer.listenerCueRotate:registerScriptHandler(onBegan, cc.Handler.EVENT_TOUCH_BEGAN)
    m_MainLayer.listenerCueRotate:registerScriptHandler(onMoved, cc.Handler.EVENT_TOUCH_MOVED)
    m_MainLayer.listenerCueRotate:registerScriptHandler(onEnded, cc.Handler.EVENT_TOUCH_ENDED)
    m_MainLayer.eventDispatcher = m_MainLayer:getEventDispatcher()
    m_MainLayer.eventDispatcher:addEventListenerWithSceneGraphPriority(m_MainLayer.listenerCueRotate, m_MainLayer)
end

--移除监听事件
function EBGameControl:removeListener()
    if m_MainLayer.eventDispatcher and m_MainLayer.listenerCueRotate then
        m_MainLayer.eventDispatcher:removeEventListener(m_MainLayer.listenerCueRotate)
        m_MainLayer.eventDispatcher = nil
    end
end

local curFineTurningPosY = 0  -- 当前微调框走到哪里了，是否需要重置位置
local isTouchWhiteBall = false --是否触摸开始时触摸到了白球
function EBGameControl:onTouchBegan(touch, event)
    if m_MainLayer:getIsSettingNode() then
        m_MainLayer:openSettingNode()
        print("===================")
        return false
    end
    --定时器在跑，result消息没收到，不是我的轮次，none和gameover的state不可以响应触摸
    if m_MainLayer:getTimeEntryIsRunning() or not EightBallGameManager:returnIsMyOperate() or EBGameControl:getGameState() == g_EightBallData.gameState.none 
    or EBGameControl:getGameState() == g_EightBallData.gameState.gameOver or not EightBallGameManager:getCanOperate() then
        return true
    end
    isTouchWhiteBall = false

    local fineTurningRect = m_MainLayer.layout_FineTurning:getBoundingBox()
    local curPos = m_MainLayer.node:convertToNodeSpace(touch:getLocation())
    if cc.rectContainsPoint(fineTurningRect, cc.p(curPos.x, curPos.y)) then
        curFineTurningPosY = m_MainLayer.panel_FineTurning:convertToNodeSpace(curPos).y
        return true
    end

    if EBGameControl:getGameState() == g_EightBallData.gameState.practise or 
    EBGameControl:getGameState() == g_EightBallData.gameState.waiting or 
    EBGameControl:getGameState() == g_EightBallData.gameState.setWhite or
    EBGameControl:getGameState() == g_EightBallData.gameState.restart then
        local whiteBallRect = m_MainLayer.whiteBall:getBoundingBox()
        local curPos = m_MainLayer.desk:convertToNodeSpace(touch:getLocation())
        if cc.rectContainsPoint(whiteBallRect, cc.p(curPos.x, curPos.y)) then
            isTouchWhiteBall = true
            m_MainLayer.whiteBall:whiteBallTouchBegan(m_MainLayer, m_MainLayer.whiteBall:getPosition())
            return true
        end
    end

    if EBGameControl:getGameState() == g_EightBallData.gameState.waiting or EBGameControl:getGameState() == g_EightBallData.gameState.hitBall
    or EBGameControl:getGameState() == g_EightBallData.gameState.practise or EBGameControl:getGameState() == g_EightBallData.gameState.setWhite then
        m_MainLayer.cue:setVisible(true)
        self:setCuePosByTouch(touch:getLocation(), true, false)
    end
    return true
end

function EBGameControl:onTouchEnded(touch, event)
    --定时器在跑，result消息没收到，不是我的轮次，none和gameover的state不可以响应触摸
    if m_MainLayer:getTimeEntryIsRunning() or not EightBallGameManager:returnIsMyOperate() or EBGameControl:getGameState() == g_EightBallData.gameState.none 
    or EBGameControl:getGameState() == g_EightBallData.gameState.gameOver or not EightBallGameManager:getCanOperate() then
        return true
    end
    local fineTurningRect = m_MainLayer.layout_FineTurning:getBoundingBox()
    local curPos = m_MainLayer.node:convertToNodeSpace(touch:getLocation())
    if cc.rectContainsPoint(fineTurningRect, cc.p(curPos.x, curPos.y)) then
        return true
    end
    isMoved = false

    if EBGameControl:getGameState() == g_EightBallData.gameState.practise or 
    EBGameControl:getGameState() == g_EightBallData.gameState.waiting or 
    EBGameControl:getGameState() == g_EightBallData.gameState.setWhite or
    EBGameControl:getGameState() == g_EightBallData.gameState.restart then
        -- 白球
        if isTouchWhiteBall then
            local _pos = m_MainLayer.desk:convertToNodeSpace(touch:getLocation())

            -- 如果在白线右边，waiting状态，不可以移出边线，但是会让球随y轴移动，增加流畅度
            local isLimitPos = EBGameControl:getGameState() == g_EightBallData.gameState.waiting
            if isLimitPos and _pos.x > 273.5 then
                local whiteShadow = m_MainLayer.whiteBall:getChildByTag(g_EightBallData.g_Border_Tag.whiteShadow)
                whiteShadow:setVisible(false)
                local moveHand = m_MainLayer.whiteBall:getChildByTag(g_EightBallData.g_Border_Tag.moveHand)
                moveHand:setVisible(false)
                local forbidden = m_MainLayer.whiteBall:getChildByTag(g_EightBallData.g_Border_Tag.forbidden)
                forbidden:setVisible(false)
                if mathMgr:checkBallLocationIsLegal(m_MainLayer,_pos,m_MainLayer.whiteBall) then
                    m_MainLayer.whiteBall:setPositionY(_pos.y)
                    m_MainLayer.whiteBall:sendSetWhiteBallMessage(_pos.x,_pos.y,m_MainLayer,true)
                    BilliardsAniMgr:setDeskTempAni(m_MainLayer,false)  --桌子白板
                end
                m_MainLayer.whiteBall:getPhysicsBody():setCategoryBitmask(0x01)
                m_MainLayer.whiteBall:getPhysicsBody():setContactTestBitmask(0x01)
                m_MainLayer.whiteBall:getPhysicsBody():setCollisionBitmask(0x03)
                return true
            end

            if not mathMgr:checkBallLocationIsOut(m_MainLayer,_pos,m_MainLayer.whiteBall) then
                m_MainLayer.whiteBall:setPosition(cc.p(_pos.x, _pos.y))
                BilliardsAniMgr:setDeskTempAni(m_MainLayer,false)  --桌子白板
            end
            m_MainLayer.whiteBall:whiteBallTouchEnded(m_MainLayer, _pos, false, isLimitPos)
            return true
        end
    end
    if EBGameControl:getGameState() == g_EightBallData.gameState.waiting or EBGameControl:getGameState() == g_EightBallData.gameState.hitBall
    or EBGameControl:getGameState() == g_EightBallData.gameState.practise or EBGameControl:getGameState() == g_EightBallData.gameState.setWhite then
        if curFineTurningPosY == 0 then
            m_MainLayer.cue:setVisible(true)
            self:setCuePosByTouch(touch:getLocation(), false, true)
        end
    end
    curFineTurningPosY = 0
end

function EBGameControl:onTouchMoved(touch, event)
    --定时器在跑，result消息没收到，不是我的轮次，none和gameover的state不可以响应触摸
    if m_MainLayer:getTimeEntryIsRunning() or not EightBallGameManager:returnIsMyOperate() or EBGameControl:getGameState() == g_EightBallData.gameState.none 
    or EBGameControl:getGameState() == g_EightBallData.gameState.gameOver or not EightBallGameManager:getCanOperate() then
        return true
    end
    local fineTurningRect = m_MainLayer.layout_FineTurning:getBoundingBox()
    local curPos = m_MainLayer.node:convertToNodeSpace(touch:getLocation())
    if cc.rectContainsPoint(fineTurningRect, cc.p(curPos.x, curPos.y)) then
        local _pos = m_MainLayer.panel_FineTurning:convertToNodeSpace(curPos)
        m_MainLayer.fineTurning_1:setPositionY(m_MainLayer.fineTurning_1:getPositionY() - curFineTurningPosY + _pos.y)
        m_MainLayer.fineTurning_2:setPositionY(m_MainLayer.fineTurning_2:getPositionY() - curFineTurningPosY + _pos.y)
        EBGameControl:setCuePosByTouch(nil, false, false,(curFineTurningPosY - _pos.y) / 200)
        curFineTurningPosY =((m_MainLayer.fineTurning_1:getPositionY() > m_MainLayer.fineTurning_2:getPositionY()) and
        { m_MainLayer.fineTurning_1:getPositionY() } or { m_MainLayer.fineTurning_2:getPositionY() })[1]
        return true
    end
    isMoved = true
    
    if EBGameControl:getGameState() == g_EightBallData.gameState.practise or 
    EBGameControl:getGameState() == g_EightBallData.gameState.waiting or 
    EBGameControl:getGameState() == g_EightBallData.gameState.setWhite or
    EBGameControl:getGameState() == g_EightBallData.gameState.restart then
        if isTouchWhiteBall then
            local _pos = m_MainLayer.desk:convertToNodeSpace(touch:getLocation())

            -- 如果在白线右边，waiting状态，不可以移出边线，但是会让球随y轴移动，增加流畅度
            local isLimitPos = EBGameControl:getGameState() == g_EightBallData.gameState.waiting
            if isLimitPos and _pos.x > 273.5 then
                if mathMgr:checkBallLocationIsLegal(m_MainLayer,_pos,m_MainLayer.whiteBall) then
                    m_MainLayer.whiteBall:setPositionY(_pos.y)
                end
                return true
            end

            if not mathMgr:checkBallLocationIsOut(m_MainLayer,_pos,m_MainLayer.whiteBall) then
                m_MainLayer.whiteBall:setPosition(cc.p(_pos.x, _pos.y))
            end
            m_MainLayer.whiteBall:whiteBallTouchMoved(m_MainLayer, _pos, false, isLimitPos)
            return true
        end
    end
    if EBGameControl:getGameState() == g_EightBallData.gameState.waiting or EBGameControl:getGameState() == g_EightBallData.gameState.hitBall
    or EBGameControl:getGameState() == g_EightBallData.gameState.practise or EBGameControl:getGameState() == g_EightBallData.gameState.setWhite then
        m_MainLayer.cue:setVisible(true)
        self:setCuePosByTouch(touch:getLocation(), false, false)
    end
end

--当前轮该做什么
local gameState = g_EightBallData.gameState.practise
function EBGameControl:setGameState(event)
    gameState = event
end

function EBGameControl:getGameState()
    return gameState
end

--比赛进程
local gameRound = g_EightBallData.gameRound.practise
function EBGameControl:setGameRound(event)
    gameRound = event
end

function EBGameControl:getGameRound()
    return gameRound
end


--发送同步球信息
function EBGameControl:sendSyncBalls(syncFrameIndex)
    if EBGameControl:getGameState() == g_EightBallData.gameState.practise then return end
    --_print("sendSyncBalls frame index = ", syncFrameIndex)
    local ballArray = { }
    ----------------------------------------------------------------------------------------------------------------------------------
    -- -- 测试输出
    -- if syncFrameIndex == 1 then
    --     _print("the white ball local pos is ", m_MainLayer.whiteBall:getPositionX(), m_MainLayer.whiteBall:getPositionY())
    --     _print("the white ball local velocity is ", m_MainLayer.whiteBall:getVelocity().x, m_MainLayer.whiteBall:getVelocity().y)
    -- end
    ----------------------------------------------------------------------------------------------------------------------------------
    for i = 1, 16 do
        local ball = m_MainLayer.desk:getChildByTag(i - 1)
        if ball then
            ballArray[i] = ball:getBallSyncState()
            ball:syncBallState(ballArray[i]) -- 发送的同时把数据同步到物理引擎中
        end
    end
    local requestData = {
        FrameIndex = syncFrameIndex,
        BallInfoArray =
        {
            _Count = #ballArray,
            BallInfoArray = ballArray
        },
        UserID = player:getPlayerUserID(),
    }
    EBGameControl:requestEightBallCmd(g_EIGHTBALL_REG_SYNCBALLINFO, requestData)
end

--发送击球结果消息
function EBGameControl:sendHitBallsResult(currentUserID)
    print("sendHitBallsResult userid = ",currentUserID)
    if EBGameControl:getGameState() == g_EightBallData.gameState.practise then return end
    --如果击球人是我或者击打完了还没有收到结果
    if currentUserID == player:getPlayerUserID() or next(EightBallGameManager:getBallsResultPos()) == nil then
        local ballArray = { }
        for i = 1, 16 do
            local ball = m_MainLayer.desk:getChildByTag(i - 1)
            if ball then
                ballArray[i] = ball:getBallsResultState()
            end
        end
        local _processResult = EightBallGameManager:getHitBallsProcess()
        local requestData = {
            UserID = player:getPlayerUserID(),
            SeatID = dmgr:getPlayerSeatIDByUserID(UserID),
            Result = 0,-- 待添加，这里是击球结果，是否犯规之类的
            BallInfoArray =
            {
                _Count = #ballArray,
                BallInfoArray = ballArray
            },
            CollisionBorderCount = _processResult.collisionBorderCount,
            FirstCollisionIndex = _processResult.firstCollisionIndex,
            FirstInHoleBall = _processResult.firstInHoleBall,
        }
        EBGameControl:requestEightBallCmd(g_EIGHTBALL_REQ_HITBALLRESULTREQ, requestData)
    end
end

--封装一下(发送协议)
function EBGameControl:requestEightBallCmd(methodID,requestData)
    if EBGameControl:getGameState() ~= g_EightBallData.gameState.practise then
        ClientNetManager.getInstance():requestCmd(methodID, requestData, G_ProtocolType.EIGHTBALL)
    end
end

return EBGameControl