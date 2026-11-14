package com.angomovie.angomovie_iptv.data.local

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import android.content.Context
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LocalMediaDatabaseTest {
    private lateinit var database: LocalMediaDatabase
    private lateinit var dao: LocalMediaDao

    @Before
    fun createDatabase() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext<Context>(),
            LocalMediaDatabase::class.java,
        ).allowMainThreadQueries().build()
        dao = database.localMediaDao()
    }

    @After
    fun closeDatabase() {
        database.close()
    }

    @Test
    fun favoriteCanBeReadAndRemovedByStableChannelId() {
        dao.insertFavorite(
            FavoriteChannelEntity(
                channelId = "channel-1",
                name = "Canal de teste",
                logoUrl = "",
                groupTitle = "Angola",
                tvgId = null,
                addedAt = 100L,
            ),
        )

        assertEquals(listOf("channel-1"), dao.getFavoriteIds())
        assertEquals("Canal de teste", dao.getFavorite("channel-1")?.name)

        dao.deleteFavorite("channel-1")
        assertEquals(emptyList<String>(), dao.getFavoriteIds())
        assertNull(dao.getFavorite("channel-1"))
    }

    @Test
    fun watchHistoryIsOrderedAndCanBeCleared() {
        dao.insertHistoryEntry(history("older", 100L, 1))
        dao.insertHistoryEntry(history("newer", 200L, 3))

        val latest = dao.getWatchHistory(100)
        assertEquals(listOf("newer", "older"), latest.map { it.channelId })
        assertEquals(3, latest.first().playCount)

        dao.trimWatchHistory(1)
        assertEquals(listOf("newer"), dao.getWatchHistory(100).map { it.channelId })

        dao.clearWatchHistory()
        assertEquals(emptyList<WatchHistoryEntity>(), dao.getWatchHistory(100))
    }

    private fun history(id: String, playedAt: Long, plays: Int) =
        WatchHistoryEntity(
            channelId = id,
            name = id,
            logoUrl = "",
            groupTitle = "Geral",
            tvgId = null,
            lastPlayedAt = playedAt,
            playCount = plays,
        )
}
