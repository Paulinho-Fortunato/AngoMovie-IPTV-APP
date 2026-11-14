package com.angomovie.angomovie_iptv.data.local

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Callable
import java.util.concurrent.Executors

/** Bridges the Flutter UI to Room without doing SQLite work on the main thread. */
class LocalMediaChannelHandler(context: Context) : MethodChannel.MethodCallHandler {
    private val database = LocalMediaDatabase.getInstance(context)
    private val dao = database.localMediaDao()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (!SUPPORTED_METHODS.contains(call.method)) {
            result.notImplemented()
            return
        }

        ioExecutor.execute {
            try {
                val value = execute(call)
                mainHandler.post { result.success(value) }
            } catch (error: IllegalArgumentException) {
                mainHandler.post {
                    result.error("INVALID_ARGUMENTS", "Dados locais inválidos.", null)
                }
            } catch (_: Exception) {
                // Do not include call arguments in errors; they originate in user playlist data.
                mainHandler.post {
                    result.error("LOCAL_STORAGE_ERROR", "Não foi possível guardar os dados locais.", null)
                }
            }
        }
    }

    private fun execute(call: MethodCall): Any? {
        val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        return when (call.method) {
            "favorites.getIds" -> dao.getFavoriteIds()
            "favorites.toggle" -> toggleFavorite(arguments)
            "favorites.importLegacy" -> importLegacyFavorites(arguments)
            "history.record" -> recordPlayback(arguments)
            "history.list" -> dao.getWatchHistory(HISTORY_LIMIT).map { it.toMap() }
            "history.clear" -> {
                dao.clearWatchHistory()
                true
            }
            else -> null
        }
    }

    private fun toggleFavorite(arguments: Map<*, *>): Boolean =
        database.runInTransaction(Callable {
            val channelId = arguments.requiredString("channelId")
            val existing = dao.getFavorite(channelId)
            if (existing != null) {
                dao.deleteFavorite(channelId)
                false
            } else {
                dao.insertFavorite(
                    arguments.toFavoriteEntity(channelId, System.currentTimeMillis()),
                )
                true
            }
        })

    private fun importLegacyFavorites(arguments: Map<*, *>): Boolean {
        val channels = arguments["channels"] as? List<*> ?: emptyList<Any>()
        val timestamp = System.currentTimeMillis()
        channels.forEach { rawChannel ->
            val channel = rawChannel as? Map<*, *> ?: return@forEach
            val channelId = channel["channelId"] as? String
                ?: channel["id"] as? String
                ?: return@forEach
            if (channelId.isBlank() || dao.getFavorite(channelId) != null) return@forEach
            dao.insertFavorite(channel.toFavoriteEntity(channelId, timestamp))
        }
        return true
    }

    private fun recordPlayback(arguments: Map<*, *>): Map<String, Any?> =
        database.runInTransaction(Callable {
            val channelId = arguments.requiredString("channelId")
            val previous = dao.getHistoryEntry(channelId)
            val entry = WatchHistoryEntity(
                channelId = channelId,
                name = arguments.optionalString("name"),
                logoUrl = arguments.optionalString("logoUrl"),
                groupTitle = arguments.optionalString("groupTitle"),
                tvgId = arguments.optionalNullableString("tvgId"),
                lastPlayedAt = System.currentTimeMillis(),
                playCount = (previous?.playCount ?: 0) + 1,
            )
            dao.insertHistoryEntry(entry)
            dao.trimWatchHistory(HISTORY_LIMIT)
            entry.toMap()
        })

    private fun Map<*, *>.requiredString(key: String): String =
        (this[key] as? String)?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("Missing required field")

    private fun Map<*, *>.optionalString(key: String): String =
        (this[key] as? String)?.take(2_000) ?: ""

    private fun Map<*, *>.optionalNullableString(key: String): String? =
        (this[key] as? String)?.take(2_000)?.takeIf { it.isNotBlank() }

    private fun Map<*, *>.toFavoriteEntity(channelId: String, addedAt: Long) =
        FavoriteChannelEntity(
            channelId = channelId,
            name = optionalString("name"),
            logoUrl = optionalString("logoUrl"),
            groupTitle = optionalString("groupTitle"),
            tvgId = optionalNullableString("tvgId"),
            addedAt = addedAt,
        )

    private fun FavoriteChannelEntity.toMap(): Map<String, Any?> = mapOf(
        "channelId" to channelId,
        "name" to name,
        "logoUrl" to logoUrl,
        "groupTitle" to groupTitle,
        "tvgId" to tvgId,
        "addedAt" to addedAt,
    )

    private fun WatchHistoryEntity.toMap(): Map<String, Any?> = mapOf(
        "channelId" to channelId,
        "name" to name,
        "logoUrl" to logoUrl,
        "groupTitle" to groupTitle,
        "tvgId" to tvgId,
        "lastPlayedAt" to lastPlayedAt,
        "playCount" to playCount,
    )

    companion object {
        private const val HISTORY_LIMIT = 100
        private val mainHandler = Handler(Looper.getMainLooper())
        private val ioExecutor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "angomovie-local-media").apply { isDaemon = true }
        }
        private val SUPPORTED_METHODS = setOf(
            "favorites.getIds",
            "favorites.toggle",
            "favorites.importLegacy",
            "history.record",
            "history.list",
            "history.clear",
        )
    }
}
