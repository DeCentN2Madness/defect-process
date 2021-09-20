module Configs.All.Level
    ( LevelConfig(..)
    ) where

import Data.Aeson.Types (FromJSON, genericParseJSON, parseJSON)
import GHC.Generics     (Generic)
import qualified Data.List.NonEmpty as NE

import Level.Room.ArenaWalls.EnemySpawn.Types
import Level.Room.ArenaWalls.JSON
import Util
import World.Util
import {-# SOURCE #-} Enemy.Util

data LevelConfig = LevelConfig
    { _maxNumArenas          :: Int
    , _runProgressScreenSecs :: Secs
    , _endBossGoldValue      :: GoldValue
    , _endBossSpawnWaitSecs  :: Secs
    , _endWarpOutWaitSecs    :: Secs

    , _itemPickupWeaponGoldValue               :: GoldValue
    , _itemPickupGunGoldValue                  :: GoldValue
    , _itemPickupMovementSkillGoldValue        :: GoldValue
    , _itemPickupStoneFormSkillGoldValue       :: GoldValue
    , _itemPickupFlightSkillGoldValue          :: GoldValue
    , _itemPickupFastFallSkillGoldValue        :: GoldValue
    , _itemPickupMeterUpgradeGoldValue         :: GoldValue
    , _itemPickupDoubleJumpUpgradeGoldValue    :: GoldValue
    , _itemPickupMovementSkillUpgradeGoldValue :: GoldValue
    , _itemPickupHealthGoldValue               :: GoldValue
    , _itemPickupHealthMultiplicandGoldValue   :: GoldValue

    , _arenaWallsGoldDrops :: NE.NonEmpty RoomArenaWallsGoldDropJSON
    , _arenaWallsMaxWidths :: [RoomArenaWallsMaxWidthJSON]

    , _speedRailAcceleration             :: Acceleration
    , _speedRailMaxSpeed                 :: Speed
    , _speedRailMaxPlayerTurnaroundSpeed :: Speed
    , _speedRailSlowSpeedThreshold       :: Speed

    , _springLauncherVelY          :: VelY
    , _springLauncherWidth         :: Float
    , _springLauncherHeight        :: Float
    , _springLauncherSurfaceWidth  :: Float
    , _springLauncherSurfaceHeight :: Float

    , _eventLightningInitialRemainingWaves :: Int
    , _eventLightningPerWaveGoldValue      :: GoldValue

    , _eventBouncingBallAliveSecs           :: Secs
    , _eventBouncingBallDropCooldownSecs    :: Secs
    , _eventBouncingBallMinSpeed            :: Speed
    , _eventBouncingBallMaxSpeed            :: Speed
    , _eventBouncingBallDropMeleeGoldValue  :: GoldValue
    , _eventBouncingBallDropRangedGoldValue :: GoldValue
    , _eventBouncingBallLockOnReticleData   :: EnemyLockOnReticleData

    , _enemySpawnWaves :: NE.NonEmpty EnemySpawnWaveJSON
    }
    deriving Generic

instance FromJSON LevelConfig where
    parseJSON = genericParseJSON aesonFieldDropUnderscore
