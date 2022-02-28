module Player.Util
    ( playerLerpOffset
    , playerShoulderPos
    , playerRawAimTargetWithAngle
    , playerAimTarget
    , playerAimPos
    , playerAimAngle
    , playerAimAngleWithPos
    , playerAimVec
    , playerMovementSkillStatus
    , playerOpacity
    , canSpendPlayerMeter
    , isPlayerAttackVelAirStall
    , isPlayerHurtInvincible
    , isPlayerInSpawnAnim
    , isPlayerInDeathAnim
    , isPlayerInWarpOutAnim
    , inPlayerInputBuffer
    , inPlayerTapInputBuffer
    , isPlayerInputBufferQCF
    , cancelPlayerMovementSkill
    , resetPlayerOnChangeWorldRoom
    , setPlayerSecondarySkillManagerOrder
    , updatePlayerBufferedInput
    , updatePlayerBufferedInputInHitlag
    ) where

import Control.Monad.IO.Class (MonadIO)
import Data.Maybe             (fromMaybe)

import Attack.Types
import Configs
import Configs.All.Player
import Level.Room.Types
import Level.Room.Util
import Msg
import Player.AimBody
import Player.BufferedInputState
import Player.Flags
import Player.LockOnAim.Util
import Player.Meter
import Player.MovementSkill
import Player.SecondarySkill.Manager.Util
import Player.SecondarySkill.Types
import Player.Sprites
import Player.TimersCounters
import Player.Types
import Util
import Window.Graphics
import Window.InputState

playerLerpOffset :: (GraphicsRead m, MonadIO m) => Player -> m Pos2
playerLerpOffset player = graphicsLerpOffset (Vel2 velX' velY')
    where
        Vel2 velX velY = _vel (player :: Player)
        flags          = _flags (player :: Player)
        velX'          = if _touchingWall flags then 0.0 else velX
        velY'          = if _touchingGround flags then 0.0 else velY

playerShoulderPos :: Player -> Pos2
playerShoulderPos player = calculateShoulderPos playerCfg pos
    where
        pos       = _pos (player :: Player)
        playerCfg = _config (player :: Player)

playerRawAimTarget :: Player -> Float -> Pos2
playerRawAimTarget player distance = playerRawAimTargetWithPos player distance aimPos
    where aimPos = _aimPos (player :: Player)

playerRawAimTargetWithPos :: Player -> Float -> Pos2 -> Pos2
playerRawAimTargetWithPos player distance aimPos =
    shoulderPos `vecAdd` (vecNormalize aimOffset `vecMul` distance)
        where
            shoulderPos = playerShoulderPos player
            aimOffset   = aimPos `vecSub` shoulderPos

playerRawAimTargetWithAngle :: Player -> Float -> Radians -> Pos2
playerRawAimTargetWithAngle player distance aimAngle =
    shoulderPos `vecAdd` (toPos2 $ aimNormVec `vecMul` distance)
        where
            shoulderPos = playerShoulderPos player
            aimNormVec  = vecNormalize $ Vec2 (cos aimAngle) (sin aimAngle)

lockOnAimPos :: Player -> Maybe Pos2
lockOnAimPos player = playerLockOnAimPos $ _lockOnAim player

playerAimTarget :: Player -> Float -> Pos2
playerAimTarget player distance = case lockOnAimPos player of
    Just lockOnPos -> playerRawAimTargetWithPos player distance lockOnPos
    Nothing        -> playerRawAimTarget player distance

playerAimPos :: Player -> Pos2
playerAimPos player = fromMaybe (_aimPos player) (lockOnAimPos player)

playerAimAngle :: Player -> Radians
playerAimAngle player = playerAimAngleWithPos player aimPos
    where aimPos = playerAimPos player

playerAimAngleWithPos :: Player -> Pos2 -> Radians
playerAimAngleWithPos player aimPos = calculateAimAngle playerCfg pos aimPos
    where
        playerCfg = _config (player :: Player)
        pos       = _pos (player :: Player)

playerAimVec :: Player -> Vec2
playerAimVec player = calculateAimVec playerCfg pos aimPos
    where
        playerCfg = _config (player :: Player)
        pos       = _pos (player :: Player)
        aimPos    = playerAimPos player

playerMovementSkillStatus :: Player -> MovementSkillStatus
playerMovementSkillStatus player = fromMaybe InactiveMovement $ do
    Some ms <- _movementSkill player
    Just $ _status ms

playerOpacity :: Player -> Opacity
playerOpacity player
    | hurtInvincibleTtl > 0.0 && hurtInvincibleTtl <= _hurtInvincibleFadedSecs cfg = _hurtInvincibleFadedOpacity cfg
    | otherwise                                                                    = FullOpacity
    where
        hurtInvincibleTtl = _hurtInvincibleTtl $ _timersCounters player
        cfg               = _config (player :: Player)

canSpendPlayerMeter :: MeterValue -> Player -> Bool
canSpendPlayerMeter meterVal player = meterVal <= playerMeterValue (_meter player)

isPlayerAttackVelAirStall :: Vel2 -> Player -> Bool
isPlayerAttackVelAirStall (Vel2 _ atkVelY) player = atkVelY >= 0.0 && atkVelY < airStallThresholdVelY
    where airStallThresholdVelY = _airStallThresholdVelY $ _config (player :: Player)

isPlayerHurtInvincible :: Player -> Bool
isPlayerHurtInvincible player = _hurtInvincibleTtl (_timersCounters player) > 0.0

isPlayerInSpawnAnim :: Player -> Bool
isPlayerInSpawnAnim player = spr == _spawn (_sprites player)
    where spr = _sprite (player :: Player)

isPlayerInDeathAnim :: Player -> Bool
isPlayerInDeathAnim player = spr == _death (_sprites player)
    where spr = _sprite (player :: Player)

isPlayerInWarpOutAnim :: Player -> Bool
isPlayerInWarpOutAnim player = spr == _warpOut (_sprites player)
    where spr = _sprite (player :: Player)

inPlayerInputBuffer :: PlayerInput -> Player -> Bool
inPlayerInputBuffer input player = input `inPlayerBufferedInputState` _bufferedInputState player

inPlayerTapInputBuffer :: [PlayerInput] -> Player -> Bool
inPlayerTapInputBuffer inputs player = inPlayerBufferedInputStateTapInputs inputs (_bufferedInputState player)

isPlayerInputBufferQCF :: Direction -> Player -> Bool
isPlayerInputBufferQCF dir player = isPlayerBufferedInputStateQCF dir (_bufferedInputState player)

cancelPlayerMovementSkill :: Player -> Player
cancelPlayerMovementSkill player = player {_movementSkill = cancel <$> _movementSkill player}
    where cancel = \(Some ms) -> Some $ cancelMovementSkill ms

resetPlayerOnChangeWorldRoom :: Room -> PosY -> Player -> Player
resetPlayerOnChangeWorldRoom room playerOffsetY player
    | isToTransitionRoomType roomType || isChallengeRoomType roomType || roomType == endHallwayRoomType = player'
        { _pos    = roomSpawnPos
        , _vel    = Vel2 0.0 0.1
        , _attack = Nothing
        }

    | otherwise =
        let spawnPos = roomSpawnPos `vecAdd` Pos2 0.0 playerOffsetY
        in player'
            { _pos    = spawnPos
            , _attack = (\atk -> (atk :: Attack) {_pos = spawnPos}) <$> _attack player'
            }

    where
        roomType     = _type (room :: Room)
        player'      = cancelPlayerMovementSkill player
        roomSpawnPos = _playerSpawnPos room

setPlayerSecondarySkillManagerOrder
    :: Maybe SecondarySkillType
    -> Maybe SecondarySkillType
    -> Maybe SecondarySkillType
    -> Player
    -> Player
setPlayerSecondarySkillManagerOrder neutralSlotType upSlotType downSlotType player = player
    { _secondarySkillManager =
        setSecondarySkillManagerOrder neutralSlotType upSlotType downSlotType (_secondarySkillManager player)
    }

updatePlayerBufferedInput :: (ConfigsRead m, InputRead m, MsgsRead UpdatePlayerMsgsPhase m) => Player -> m Player
updatePlayerBufferedInput player = do
    bufferedInputState <- updatePlayerBufferedInputState player (_bufferedInputState player)
    return $ (player :: Player) {_bufferedInputState = bufferedInputState}

updatePlayerBufferedInputInHitlag :: InputRead m => Player -> m Player
updatePlayerBufferedInputInHitlag player = do
    bufferedInputState <- updatePlayerBufferedInputStateInHitlag $ _bufferedInputState player
    return $ (player :: Player) {_bufferedInputState = bufferedInputState}
