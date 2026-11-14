package com.angomovie.angomovie_iptv.data.local

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase

/**
 * Local metadata for a favorite. Stream URLs are deliberately not persisted here:
 * provider URLs may contain credentials and are already part of the playlist cache.
 */
@Entity(tableName = "favorite_channels")
data class FavoriteChannelEntity(
    @PrimaryKey val channelId: String,
    val name: String,
    val logoUrl: String,
    val groupTitle: String,
    val tvgId: String?,
    val addedAt: Long,
)

/** One row per channel, retaining its most recent viewing time and total play count. */
@Entity(tableName = "watch_history")
data class WatchHistoryEntity(
    @PrimaryKey val channelId: String,
    val name: String,
    val logoUrl: String,
    val groupTitle: String,
    val tvgId: String?,
    val lastPlayedAt: Long,
    val playCount: Int,
)

@Dao
interface LocalMediaDao {
    @Query("SELECT channelId FROM favorite_channels ORDER BY addedAt DESC")
    fun getFavoriteIds(): List<String>

    @Query("SELECT * FROM favorite_channels WHERE channelId = :channelId LIMIT 1")
    fun getFavorite(channelId: String): FavoriteChannelEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insertFavorite(favorite: FavoriteChannelEntity)

    @Query("DELETE FROM favorite_channels WHERE channelId = :channelId")
    fun deleteFavorite(channelId: String)

    @Query("SELECT * FROM watch_history ORDER BY lastPlayedAt DESC LIMIT :limit")
    fun getWatchHistory(limit: Int): List<WatchHistoryEntity>

    @Query("SELECT * FROM watch_history WHERE channelId = :channelId LIMIT 1")
    fun getHistoryEntry(channelId: String): WatchHistoryEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insertHistoryEntry(entry: WatchHistoryEntity)

    @Query("DELETE FROM watch_history")
    fun clearWatchHistory()

    @Query("""
        DELETE FROM watch_history
        WHERE channelId NOT IN (
            SELECT channelId FROM watch_history ORDER BY lastPlayedAt DESC LIMIT :keepCount
        )
    """)
    fun trimWatchHistory(keepCount: Int)
}

@Database(
    entities = [FavoriteChannelEntity::class, WatchHistoryEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class LocalMediaDatabase : RoomDatabase() {
    abstract fun localMediaDao(): LocalMediaDao

    companion object {
        private const val DATABASE_NAME = "angomovie_local_media.db"

        @Volatile
        private var instance: LocalMediaDatabase? = null

        fun getInstance(context: Context): LocalMediaDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    LocalMediaDatabase::class.java,
                    DATABASE_NAME,
                ).build().also { instance = it }
            }
    }
}
