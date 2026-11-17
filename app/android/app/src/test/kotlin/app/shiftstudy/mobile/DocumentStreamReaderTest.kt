package app.shiftstudy.mobile

import java.io.ByteArrayInputStream
import java.io.IOException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class DocumentStreamReaderTest {
    @Test
    fun acceptsAStreamExactlyAtItsByteLimit() {
        val bytes = byteArrayOf(1, 2, 3, 4)

        assertArrayEquals(bytes, DocumentStreamReader.readLimited(ByteArrayInputStream(bytes), bytes.size))
    }

    @Test
    fun rejectsAStreamThatExceedsItsByteLimit() {
        val stream = ByteArrayInputStream(byteArrayOf(1, 2, 3, 4, 5))

        assertThrows(IOException::class.java) {
            DocumentStreamReader.readLimited(stream, 4)
        }
    }
}
