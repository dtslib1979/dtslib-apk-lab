package com.dtslib.overlaydualsub

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.dtslib.overlaydualsub.service.OverlayService
import com.dtslib.overlaydualsub.ui.theme.OverlayDualSubTheme

class MainActivity : ComponentActivity() {

    // Mode switch: true = Mock, false = WebSocket
    private val useMock = true

    private var hasOverlay by mutableStateOf(false)
    private var hasMic by mutableStateOf(false)
    private var isRunning by mutableStateOf(false)

    private val micLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasMic = granted
        if (!granted) {
            toast("마이크 권한이 필요합니다")
        }
    }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        checkPerms()
        setContent {
            OverlayDualSubTheme {
                MainScreen()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        checkPerms()
    }

    private fun checkPerms() {
        hasOverlay = Settings.canDrawOverlays(this)
        hasMic = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun reqOverlay() {
        val i = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        startActivity(i)
    }

    private fun reqMic() {
        micLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    private fun startSvc() {
        if (!hasOverlay) {
            toast("오버레이 권한을 먼저 허용하세요")
            return
        }
        val i = Intent(this, OverlayService::class.java).apply {
            putExtra("useMock", useMock)
        }
        ContextCompat.startForegroundService(this, i)
        isRunning = true
        toast("오버레이 시작")
    }

    private fun stopSvc() {
        stopService(Intent(this, OverlayService::class.java))
        isRunning = false
        toast("오버레이 종료")
    }

    private fun toast(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
    }

    @Composable
    fun MainScreen() {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    text = "Overlay Dual Subtitle",
                    style = MaterialTheme.typography.headlineMedium
                )

                Spacer(Modifier.height(32.dp))

                // Overlay permission
                PermRow(
                    label = "오버레이 권한",
                    granted = hasOverlay,
                    onRequest = { reqOverlay() }
                )

                Spacer(Modifier.height(16.dp))

                // Mic permission
                PermRow(
                    label = "마이크 권한",
                    granted = hasMic,
                    onRequest = { reqMic() }
                )

                Spacer(Modifier.height(32.dp))

                // Start/Stop
                Button(
                    onClick = { if (isRunning) stopSvc() else startSvc() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    enabled = hasOverlay
                ) {
                    Text(if (isRunning) "Stop" else "Start")
                }

                Spacer(Modifier.height(16.dp))

                Text(
                    text = "Mode: ${if (useMock) "Mock" else "WebSocket"}",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }

    @Composable
    fun PermRow(
        label: String,
        granted: Boolean,
        onRequest: () -> Unit
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label)
            if (granted) {
                Text("✓", color = MaterialTheme.colorScheme.primary)
            } else {
                TextButton(onClick = onRequest) {
                    Text("허용")
                }
            }
        }
    }
}
