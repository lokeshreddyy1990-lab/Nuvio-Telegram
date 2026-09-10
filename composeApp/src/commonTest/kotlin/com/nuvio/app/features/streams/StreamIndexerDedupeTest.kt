package com.nuvio.app.features.streams

import kotlin.test.Test
import kotlin.test.assertEquals

class StreamIndexerDedupeTest {
    @Test
    fun `same infoHash from different indexers collapses to one stream`() {
        val nyaa = torrent(
            name = "1080p Nyaa",
            infoHash = "ABCDEF0123456789ABCDEF0123456789ABCDEF01",
            indexer = "Nyaa",
        )
        val rarbg = torrent(
            name = "1080p RARBG",
            infoHash = "abcdef0123456789abcdef0123456789abcdef01",
            indexer = "RARBG",
        )

        val result = listOf(nyaa, rarbg).deduplicatedIndexerStreams()
        assertEquals(listOf(nyaa), result)
    }

    @Test
    fun `same hash keeps distinct file indexes`() {
        val first = torrent(name = "E01", infoHash = "hashhashhashhashhashhashhashhashhashhash", fileIdx = 0)
        val second = torrent(name = "E02", infoHash = "hashhashhashhashhashhashhashhashhashhash", fileIdx = 1)

        assertEquals(2, listOf(first, second).deduplicatedIndexerStreams().size)
    }

    @Test
    fun `cached duplicate is preferred over uncached`() {
        val uncached = torrent(
            name = "Uncached",
            infoHash = "ABCDEF0123456789ABCDEF0123456789ABCDEF01",
            indexer = "Nyaa",
            cacheState = StreamDebridCacheState.NOT_CACHED,
        )
        val cached = torrent(
            name = "Cached",
            infoHash = "ABCDEF0123456789ABCDEF0123456789ABCDEF01",
            indexer = "RARBG",
            cacheState = StreamDebridCacheState.CACHED,
        )

        val result = listOf(uncached, cached).deduplicatedIndexerStreams()
        assertEquals(listOf(cached), result)
    }

    @Test
    fun `parser drops indexer duplicates from addon payload`() {
        val streams = StreamParser.parse(
            payload =
                """
                {
                  "streams": [
                    {
                      "infoHash": "ABCDEF0123456789ABCDEF0123456789ABCDEF01",
                      "name": "1080p",
                      "title": "Nyaa",
                      "behaviorHints": { "filename": "Show.S01E01.mkv" }
                    },
                    {
                      "infoHash": "abcdef0123456789abcdef0123456789abcdef01",
                      "name": "1080p",
                      "title": "1337x",
                      "behaviorHints": { "filename": "Show.S01E01.mkv" }
                    }
                  ]
                }
                """.trimIndent(),
            addonName = "AIOStreams",
            addonId = "addon:aiostreams",
        )

        assertEquals(1, streams.size)
        assertEquals("Nyaa", streams.single().title)
    }

    private fun torrent(
        name: String,
        infoHash: String,
        indexer: String? = null,
        fileIdx: Int? = null,
        cacheState: StreamDebridCacheState? = null,
    ): StreamItem = StreamItem(
        name = name,
        title = indexer,
        infoHash = infoHash,
        fileIdx = fileIdx,
        addonName = "AIOStreams",
        addonId = "addon:aiostreams",
        clientResolve = StreamClientResolve(
            infoHash = infoHash,
            fileIdx = fileIdx,
            stream = StreamClientResolveStream(
                raw = StreamClientResolveRaw(indexer = indexer),
            ),
        ),
        debridCacheStatus = cacheState?.let { state ->
            StreamDebridCacheStatus(
                providerId = "torbox",
                providerName = "TorBox",
                state = state,
            )
        },
    )
}
