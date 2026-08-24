package com.sirandev.flashnote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Parcel
import android.os.RemoteException
import android.util.Log

/**
 * Adapter for Xiaomi HyperOS "公平运行内存机制" (Fair Running Memory mechanism).
 *
 * The system sends a broadcast (`itgsa.intent.action.TRIM`) when the app's
 * physical (PSS) or Java-heap memory approaches a threshold. On receiving it we
 * must (within 3s) release memory / persist state and call back the system via
 * the supplied Binder so the system knows we acknowledged it. Failing to adapt
 * means the app cannot save its state before being killed and is more likely to
 * be reclaimed in the background.
 *
 * See: https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2304
 */
class FairMemoryReceiver : IBinder.DeathRecipient {
    private val tag = "FairMemoryReceiver"

    // TRIM action broadcast by the fair-memory mechanism.
    private val actionTrim = "itgsa.intent.action.TRIM"

    // First transaction code used to reply to the system callback binder.
    private val transactionExceptionReply = IBinder.FIRST_CALL_TRANSACTION

    private var remote: IBinder? = null
    private var initialized = false
    private var handler: android.os.Handler? = null

    override fun binderDied() {
        synchronized(this) {
            remote?.let {
                try {
                    it.unlinkToDeath(this, 0)
                } catch (_: RemoteException) {
                }
            }
            remote = null
        }
    }

    fun initialize(context: Context) {
        synchronized(this) {
            if (initialized) return
            val thread = android.os.HandlerThread(tag)
            thread.start()
            handler = android.os.Handler(thread.looper)
            val filter = IntentFilter(actionTrim)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(receiver, filter, null, handler, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(receiver, filter, null, handler)
            }
            initialized = true
        }
    }

    fun dispose(context: Context) {
        synchronized(this) {
            if (!initialized) return
            try {
                context.unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
            handler?.looper?.quitSafely()
            handler = null
            remote = null
            initialized = false
        }
    }

    /**
     * Invoked on the broadcast. [onTrim] lets the host (MainActivity) forward the
     * event to Flutter so it can clear image caches / persist drafts.
     */
    var onTrim: ((notifyType: Int, notifyId: Int, isKill: Boolean) -> Unit)? = null

    private val receiver =
        object : BroadcastReceiver() {
            override fun onReceive(
                context: Context,
                intent: Intent,
            ) {
                if (actionTrim != intent.action) return
                val data = intent.extras ?: return
                val common = data.getBundle("common") ?: return
                val notifyType = common.getInt("notifyType")
                val notifyId = common.getInt("notifyId")
                val callback = common.getBinder("callback") ?: return
                // Capture the system callback binder so we can acknowledge it.
                if (!bindCallback(callback)) return
                // notifyType 1000 = physical memory limit, 2000 = Java heap limit.
                // Both may be a kill signal requiring immediate state backup.
                val isKill = notifyType == 1000 || notifyType == 2000
                onTrim?.invoke(notifyType, notifyId, isKill)
                // Always acknowledge the system promptly (best-effort release is
                // done asynchronously by the Flutter side). The system times out
                // in 3s, so we reply as soon as we have handed off the work.
                reply(notifyType, notifyId, 0, null)
            }
        }

    private fun reply(
        notifyType: Int,
        notifyId: Int,
        result: Int,
        extra: Bundle?,
    ) {
        synchronized(this) {
            val binder = remote ?: return
            val data = Parcel.obtain()
            val replyParcel = Parcel.obtain()
            try {
                data.writeInt(notifyType)
                data.writeInt(notifyId)
                data.writeInt(result)
                data.writeBundle(extra ?: Bundle())
                binder.transact(transactionExceptionReply, data, replyParcel, IBinder.FLAG_ONEWAY)
                replyParcel.readException()
            } catch (e: Exception) {
                Log.e(tag, "reply failed.", e)
            } finally {
                replyParcel.recycle()
                data.recycle()
            }
        }
    }

    /** Stores the system callback binder so we can acknowledge the broadcast. */
    private fun bindCallback(callback: IBinder): Boolean {
        synchronized(this) {
            if (remote != null) return true
            return try {
                remote = callback
                remote?.linkToDeath(this, 0)
                true
            } catch (_: RemoteException) {
                remote = null
                false
            }
        }
    }
}
