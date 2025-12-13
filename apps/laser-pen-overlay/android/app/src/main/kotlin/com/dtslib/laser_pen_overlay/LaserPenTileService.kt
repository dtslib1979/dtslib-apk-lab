package com.dtslib.laser_pen_overlay

import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class LaserPenTileService : TileService() {
    
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }
    
    override fun onClick() {
        super.onClick()
        
        // 서비스 시작 또는 토글
        val intent = Intent(this, OverlayService::class.java).apply {
            action = if (OverlayService.isOverlayVisible) {
                OverlayService.ACTION_HIDE
            } else {
                // 서비스가 없으면 시작, 있으면 SHOW
                if (OverlayService.instance == null) {
                    null // 기본 시작
                } else {
                    OverlayService.ACTION_SHOW
                }
            }
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        
        // 딜레이 후 상태 업데이트
        qsTile?.let { tile ->
            tile.state = if (OverlayService.isOverlayVisible) {
                Tile.STATE_INACTIVE
            } else {
                Tile.STATE_ACTIVE
            }
            tile.updateTile()
        }
    }
    
    private fun updateTile() {
        qsTile?.let { tile ->
            tile.state = if (OverlayService.isOverlayVisible) {
                Tile.STATE_ACTIVE
            } else {
                Tile.STATE_INACTIVE
            }
            tile.label = "Laser Pen"
            tile.contentDescription = if (OverlayService.isOverlayVisible) {
                "판서 활성화됨"
            } else {
                "판서 비활성화됨"
            }
            tile.updateTile()
        }
    }
}
