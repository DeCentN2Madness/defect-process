module Enemy.All.Boss.BlobProjectile
    ( mkBlobProjectile
    ) where

import Control.Monad.IO.Class (MonadIO)
import Data.Maybe             (fromMaybe)
import qualified Data.Set as S

import Attack
import Attack.Hit
import Collision
import Configs.All.Enemy
import Configs.All.Enemy.Boss
import Constants
import Enemy.All.Boss.AttackDescriptions
import Enemy.All.Boss.Data
import FileCache
import Id
import Msg
import Particle.All.Simple
import Projectile as P
import Util
import Window.Graphics
import World.Surface.Types
import World.ZIndex

packPath             = \f -> PackResourceFilePath "data/enemies/boss-enemy-attack1.pack" f
projDisappearSprPath = packPath "attack-blob-projectile-disappear.spr" :: PackResourceFilePath
projHitSprPath       = packPath "attack-blob-projectile-hit.spr"       :: PackResourceFilePath

projHitSoundPath = "event:/SFX Events/Enemy/Boss/attack-blob-hit" :: FilePath

data BlobProjectileData = BlobProjectileData
    { _attack :: Attack
    }

mkBlobProjectileData :: Attack -> BlobProjectileData
mkBlobProjectileData atk = BlobProjectileData
    { _attack = atk
    }

mkBlobProjectile :: MonadIO m => Pos2 -> Direction -> BossEnemyData -> m (Some Projectile)
mkBlobProjectile enemyPos dir enemyData =
    let
        bossCfg               = _boss $ _config enemyData
        releaseBlobProjOffset = _releaseBlobProjOffset bossCfg `vecFlip` dir
        pos                   = enemyPos `vecAdd` releaseBlobProjOffset
        atkDesc               = _blobProjectile $ _attackDescs enemyData
    in do
        atk <- mkAttack pos dir atkDesc
        let
            vel          = attackVelToVel2 (attackVel atk) zeroVel2
            blobProjData = mkBlobProjectileData atk

        msgId  <- newId
        let hbx = fromMaybe (DummyHitbox pos) (attackHitbox atk)
        return . Some $ (mkProjectile blobProjData msgId hbx maxSecs)
            { _vel                  = vel
            , _registeredCollisions = S.fromList [ProjRegisteredPlayerCollision, ProjRegisteredSurfaceCollision]
            , _think                = thinkBlobProjectile
            , _update               = updateBlobProjectile
            , _draw                 = drawBlobProjectile
            , _processCollisions    = processCollisions
            }

thinkBlobProjectile :: Monad m => ProjectileThink BlobProjectileData m
thinkBlobProjectile blobProj = return $ thinkAttack atk
    where atk = _attack (_data blobProj :: BlobProjectileData)

updateBlobProjectile :: Monad m => ProjectileUpdate BlobProjectileData m
updateBlobProjectile blobProj = return $ blobProj
    { _data   = blobProjData'
    , _vel    = vel
    , _hitbox = const $ fromMaybe (DummyHitbox pos') (attackHitbox atk')
    , _ttl    = ttl
    }
    where
        blobProjData = _data blobProj
        atk          = _attack (blobProjData :: BlobProjectileData)
        pos          = _pos (atk :: Attack)
        vel          = attackVelToVel2 (attackVel atk) zeroVel2
        pos'         = pos `vecAdd` (toPos2 $ vel `vecMul` timeStep)
        dir          = _dir (atk :: Attack)

        atk'          = updateAttack pos' dir atk
        ttl           = if _done atk' then 0.0 else _ttl blobProj
        blobProjData' = blobProjData {_attack = atk'} :: BlobProjectileData

processCollisions :: ProjectileProcessCollisions BlobProjectileData
processCollisions collisions blobProj = foldr processCollision [] collisions
    where
        processCollision :: ProjectileCollision -> [Msg ThinkCollisionMsgsPhase] -> [Msg ThinkCollisionMsgsPhase]
        processCollision pc msgs = case pc of
            ProjPlayerCollision player              -> playerCollision player blobProj ++ msgs
            ProjSurfaceCollision hbx GeneralSurface -> surfaceCollision hbx blobProj ++ msgs
            _                                       -> msgs

playerCollision :: CollisionEntity e => e -> Projectile BlobProjectileData -> [Msg ThinkCollisionMsgsPhase]
playerCollision player blobProj =
    [ mkMsgTo (HurtMsgAttackHit atkHit) playerId
    , mkMsgTo (ProjectileMsgSetTtl 0.0) blobProjId
    , mkMsg $ ParticleMsgAddM mkHitEffect
    , mkMsg $ AudioMsgPlaySound projHitSoundPath pos
    ]
        where
            playerId    = collisionEntityMsgId player
            blobProjId  = P._msgId blobProj
            atk         = _attack (_data blobProj :: BlobProjectileData)
            atkHit      = mkAttackHit atk
            pos         = _pos (atk :: Attack)
            dir         = _dir (atk :: Attack)
            mkHitEffect = loadSimpleParticle pos dir enemyAttackProjectileZIndex projHitSprPath

surfaceCollision :: Hitbox -> Projectile BlobProjectileData -> [Msg ThinkCollisionMsgsPhase]
surfaceCollision surfaceHbx blobProj
    | hitboxTop surfaceHbx <= hitboxTop blobProjHbx =  -- crude wall/non-ground check
        [ mkMsgTo (ProjectileMsgSetTtl 0.0) blobProjId
        , mkMsg $ ParticleMsgAddM mkDisappearEffect
        ]
    | otherwise                                     = []
        where
            blobProjHbx       = (P._hitbox blobProj) blobProj
            blobProjId        = P._msgId blobProj
            atk               = _attack (_data blobProj :: BlobProjectileData)
            pos               = _pos (atk :: Attack)
            dir               = _dir (atk :: Attack)
            mkDisappearEffect = loadSimpleParticle pos dir enemyAttackProjectileZIndex projDisappearSprPath

drawBlobProjectile :: (GraphicsReadWrite m, MonadIO m) => ProjectileDraw BlobProjectileData m
drawBlobProjectile blobProj =
    let
        attack = _attack (_data blobProj :: BlobProjectileData)
        spr    = attackSprite attack
        pos    = _pos (attack :: Attack)
        vel    = P._vel blobProj
        dir    = _dir (attack :: Attack)
    in do
        pos' <- graphicsLerpPos pos vel
        drawSprite pos' dir enemyAttackProjectileZIndex spr
