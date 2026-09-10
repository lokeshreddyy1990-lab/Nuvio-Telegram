package com.nuvio.app.core.sync

import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import platform.Foundation.NSNotificationCenter
import platform.UIKit.UIApplication
import platform.UIKit.UIApplicationDidBecomeActiveNotification
import platform.UIKit.UIApplicationDidEnterBackgroundNotification
import platform.UIKit.UIApplicationState.UIApplicationStateActive
import platform.UIKit.UIApplicationState.UIApplicationStateBackground
import platform.UIKit.UIApplicationState.UIApplicationStateInactive

internal actual object AppForegroundMonitor {
    actual fun events(): Flow<AppVisibility> = callbackFlow {
        val center = NSNotificationCenter.defaultCenter

        val foregroundObserver = center.addObserverForName(
            name = UIApplicationDidBecomeActiveNotification,
            `object` = null,
            queue = null,
        ) { _ ->
            trySend(AppVisibility.Foreground)
        }

        val backgroundObserver = center.addObserverForName(
            name = UIApplicationDidEnterBackgroundNotification,
            `object` = null,
            queue = null,
        ) { _ ->
            trySend(AppVisibility.Background)
        }

        trySend(
            when (UIApplication.sharedApplication.applicationState) {
                UIApplicationStateActive,
                UIApplicationStateInactive,
                -> AppVisibility.Foreground
                UIApplicationStateBackground -> AppVisibility.Background
                else -> AppVisibility.Foreground
            },
        )

        awaitClose {
            center.removeObserver(foregroundObserver)
            center.removeObserver(backgroundObserver)
        }
    }.distinctUntilChanged()
}
