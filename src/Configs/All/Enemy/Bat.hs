module Configs.All.Enemy.Bat
    ( BatEnemyConfig(..)
    ) where

import Data.Aeson.Types (FromJSON, genericParseJSON, parseJSON)
import GHC.Generics     (Generic)

import Attack.Util
import Util
import Window.Graphics.Util
import {-# SOURCE #-} Enemy.Util

data BatEnemyConfig = BatEnemyConfig
    { _health  :: Health
    , _width   :: Float
    , _height  :: Float

    , _riseRecoverVelY  :: VelY
    , _idleSecs         :: Secs
    , _patrolSpeed      :: Speed
    , _staggerThreshold :: Stagger

    , _groundImpactEffectDrawScale :: DrawScale
    , _wallImpactEffectDrawScale   :: DrawScale

    , _hurtEffectData  :: EnemyHurtEffectData
    , _deathEffectData :: EnemyDeathEffectData
    , _spawnEffectData :: EnemySpawnEffectData
    }
    deriving Generic

instance FromJSON BatEnemyConfig where
    parseJSON = genericParseJSON aesonFieldDropUnderscore
